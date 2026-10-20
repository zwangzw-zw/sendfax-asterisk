#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (edit to match your system) --------------------------------
# Your channel technology (PJSIP is recommended)
TECH="PJSIP"
# The name of your trunk in pjsip.conf or sip.conf
TRUNK_NAME="your-trunk-name"
# The Caller ID you want to send
CALLERID="${CALLERID:-Your Name <+15551234567>}"
# Extra options for the SendFax application (d=FAX debug, f=audio fallback on T.38)
EXTRA_FAX_OPTS="df"
# Default fax priority (can be overridden with command line option)
FAX_PRIORITY="Normal"

# Asterisk spool directories (STAGE_DIR must be on the same filesystem as SPOOL_DIR)
SPOOL_DIR="/var/spool/asterisk/outgoing"
STAGE_DIR="/var/spool/asterisk/tmp"
DONE_DIR="/var/spool/asterisk/outgoing_done"
# ------------------------------------------------------------------------------

# Escape a string for safe inclusion inside a PostScript (...) literal:
# transliterates UTF-8 punctuation/accents to ASCII, expands tabs, and escapes \, (, and ).
ps_escape() {
    local input="$1"
    local ascii
    if command -v iconv >/dev/null 2>&1; then
        ascii=$(printf '%s' "$input" | tr '\t' ' ' | iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE 2>/dev/null || printf '%s' "$input")
    else
        ascii=$(printf '%s' "$input" | tr '\t' ' ')
    fi
    printf '%s' "$ascii" | LC_ALL=C tr -cd '\12\15\40-\176' | sed 's/[\\()]/\\&/g'
}

# Truncate a string with "..." if it exceeds max_len characters
truncate_str() {
    local str="$1"
    local max_len="$2"
    if (( ${#str} > max_len )); then
        printf '%s...' "${str:0:max_len-3}"
    else
        printf '%s' "$str"
    fi
}

# Function to generate fax coversheet using Ghostscript
generate_coversheet() {
    local coversheet_ps="$1"
    local total_pages="$2"
    local sender_name="$3"
    local sender_phone="$4"
    local recipient_name="$5"
    local recipient_phone="$6"
    local fax_subject="$7"
    local fax_message="$8"
    local fax_priority="$9"

    # Normalize tabs to spaces before wrapping; wrap at 75 chars for 12pt Helvetica
    # inside the 512pt message box (soft wrap at word boundaries, then hard wrap for long URLs)
    local clean_msg
    clean_msg=$(printf '%s' "$fax_message" | tr '\t' ' ')
    local wrapped_lines
    if command -v fold >/dev/null 2>&1; then
        wrapped_lines=$(printf '%s\n' "$clean_msg" | fold -s -w 75 | fold -w 75)
    elif command -v fmt >/dev/null 2>&1; then
        wrapped_lines=$(printf '%s\n' "$clean_msg" | fmt -w 75)
    else
        wrapped_lines=""
        local rem="$clean_msg"
        while [[ ${#rem} -gt 75 ]]; do
            wrapped_lines+="${rem:0:75}"$'\n'
            rem="${rem:75}"
        done
        wrapped_lines+="$rem"
    fi

    # Read wrapped lines into an array without spawning per-line subshells
    local all_lines=()
    mapfile -t all_lines <<< "$wrapped_lines"

    local max_lines=18
    local message_lines=()
    if (( ${#all_lines[@]} <= max_lines )); then
        message_lines=("${all_lines[@]}")
    else
        message_lines=("${all_lines[@]:0:max_lines-1}" "...more")
    fi

    # Guard column/line widths and escape all user-supplied fields for PostScript (...) strings
    local ps_sender_name ps_sender_phone ps_recipient_name ps_recipient_phone
    local ps_total_pages ps_priority ps_subject
    ps_sender_name=$(ps_escape "$(truncate_str "$sender_name" 34)")
    ps_sender_phone=$(ps_escape "$(truncate_str "$sender_phone" 34)")
    ps_recipient_name=$(ps_escape "$(truncate_str "$recipient_name" 34)")
    ps_recipient_phone=$(ps_escape "$(truncate_str "$recipient_phone" 34)")
    ps_total_pages=$(ps_escape "$total_pages")
    ps_priority=$(ps_escape "$(truncate_str "$fax_priority" 28)")
    ps_subject=$(ps_escape "$(truncate_str "$fax_subject" 64)")

    cat > "$coversheet_ps" << EOF
%!PS-Adobe-3.0
%%BoundingBox: 0 0 612 792
%%Title: Fax Cover Sheet
%%Creator: sendfax.sh

% Define fonts (Helvetica for crisp bilevel fax legibility at 204x196 DPI)
/TitleFont { /Helvetica-Bold findfont 20 scalefont setfont } def
/HeaderFont { /Helvetica-Bold findfont 13 scalefont setfont } def
/BodyFont { /Helvetica findfont 12 scalefont setfont } def
/SmallFont { /Helvetica findfont 9.5 scalefont setfont } def

% Colors and line width
1 setlinewidth
0 setgray

% Top decorative border (lowered to y=752/747 so transmission header has clean clearance)
50 752 moveto 562 752 lineto
50 747 moveto 562 747 lineto
stroke

% Main title
TitleFont
306 708 moveto
(FACSIMILE TRANSMISSION) dup stringwidth pop 2 div neg 0 rmoveto show

% Decorative line after title
50 685 moveto 562 685 lineto stroke

% From section (15pt leading for 12pt BodyFont prevents descender/ascender collisions)
HeaderFont
50 652 moveto (FROM:) show
BodyFont
55 635 moveto ($ps_sender_name) show
55 620 moveto ($ps_sender_phone) show

% To section (15pt leading for 12pt BodyFont)
HeaderFont
317 652 moveto (TO:) show
BodyFont
322 635 moveto ($ps_recipient_name) show
322 620 moveto ($ps_recipient_phone) show

% Pages info (15pt leading for 12pt BodyFont)
HeaderFont
50 592 moveto (PAGES:) show
BodyFont
55 575 moveto (Total Pages: $ps_total_pages) show
55 560 moveto (Including cover sheet) show

% Priority
HeaderFont
317 592 moveto (PRIORITY:) show
BodyFont
322 575 moveto ($ps_priority) show

% Subject section
HeaderFont
50 526 moveto (SUBJECT:) show
BodyFont
130 526 moveto ($ps_subject) show

% Message section
HeaderFont
50 495 moveto (MESSAGE:) show

% Message box (287pt height, fits 18 lines at 15pt leading)
50 467 moveto 562 467 lineto 562 180 lineto 50 180 lineto closepath stroke
BodyFont

EOF

    # Generate message lines dynamically (preserving blank lines for paragraph spacing)
    local y_pos=450
    local ps_line
    for i in "${!message_lines[@]}"; do
        if [[ -n "${message_lines[$i]}" ]]; then
            ps_line=$(ps_escape "${message_lines[$i]}")
            printf '%% Message line %d\n55 %d moveto (%s) show\n' "$((i + 1))" "$y_pos" "$ps_line" >> "$coversheet_ps"
        fi
        y_pos=$((y_pos - 15))  # Advance 15 points per line even for blank lines
    done

    cat >> "$coversheet_ps" << 'EOF'

% Professional footer section (12pt leading for 9.5pt SmallFont)
50 140 moveto 562 140 lineto stroke
50 135 moveto 562 135 lineto stroke

SmallFont
50 120 moveto (CONFIDENTIALITY NOTICE:) show
50 106 moveto (This facsimile transmission contains confidential information intended only) show
50 94 moveto (for the use of the individual or entity named above. If you are not the intended) show
50 82 moveto (recipient, you are hereby notified that any disclosure, copying, distribution,) show
50 70 moveto (or use of this information is strictly prohibited.) show

% Bottom decorative elements
50 50 moveto 562 50 lineto
50 45 moveto 562 45 lineto
stroke

showpage
EOF
}

# Build the header text for a given page number and stamp it onto a TIFF file.
# If reserve_band=true (used for PDF pages), the 1728x2082 page is bottom-aligned
# onto a 1728x2156 canvas first so the top 74px is a clean white banner and no
# top-edge PDF content is ever overwritten.
stamp_header() {
    local tiff_file="$1"
    local display_page_num="$2"
    local total_pages="$3"
    local reserve_band="${4:-false}"

    local header_text=""
    if [[ -n "$SENDER_INFO" ]]; then
        header_text="FROM: $SENDER_INFO"
    fi

    local to_part=""
    if [[ -n "$DEST_DISPLAY" ]]; then
        if [[ -n "$RECIPIENT_NAME" ]]; then
            local short_rcpt
            short_rcpt=$(truncate_str "$RECIPIENT_NAME" 28)
            to_part="TO: $short_rcpt ($DEST_DISPLAY)"
        else
            to_part="TO: $DEST_DISPLAY"
        fi
    fi

    if [[ -n "$to_part" ]]; then
        if [[ -n "$header_text" ]]; then
            header_text="$header_text | $to_part"
        else
            header_text="$to_part"
        fi
    fi

    if [[ -n "$header_text" ]]; then
        header_text="$header_text | $CURRENT_DATE | PAGE $display_page_num/$total_pages"
    else
        header_text="$CURRENT_DATE | PAGE $display_page_num/$total_pages"
    fi

    # Escape % as %% so ImageMagick -annotate does not expand %-escapes
    local im_header_text="${header_text//%/%%}"
    local temp_tiff="${WORK_DIR}/header-page-${display_page_num}.tiff"

    local extent_args=()
    if [[ "$reserve_band" == true ]]; then
        extent_args=(-background white -gravity South -extent 1728x2156)
    fi

    "$MAGICK_CMD" "$tiff_file" \
        "${extent_args[@]}" \
        -density 204x196 \
        -units PixelsPerInch \
        -font Helvetica \
        -gravity North \
        -pointsize 10 \
        -fill black \
        -undercolor white \
        -annotate +0+28 "$im_header_text" \
        -type Bilevel \
        -depth 1 \
        -compress Group4 \
        -define quantum:polarity=min-is-white \
        "$temp_tiff"
    mv "$temp_tiff" "$tiff_file"
}

usage() {
  local exit_code="${1:-1}"
  echo "Usage: $0 [--cover|--nocover] [--from \"Name <phone>\"] [--] <destination> <input.pdf> [subject] [message] [priority]"
  echo "Options:"
  echo "  --cover     Generate coversheet (default)"
  echo "  --nocover   Skip coversheet generation"
  echo "  -h, --help  Show this help message"
  echo ""
  echo "Destination can be:"
  echo "  - Phone number: 5551234567 or +15551234567"
  echo "  - Name with phone: \"John Smith <+15551234567>\""
  echo ""
  echo "Examples:"
  echo "  $0 5551234567 document.pdf"
  echo "  $0 --cover 5551234567 document.pdf \"Important Document\" \"Please review attached.\" \"Urgent\""
  echo "  $0 --nocover \"John Smith <+15551234567>\" document.pdf"
  echo ""
  echo "Priority options: Normal, Urgent, High, Low (default: Normal)"
  exit "$exit_code"
}


# --- Input Validation and System Checks ---

# Default coversheet setting
GENERATE_COVERSHEET=true

# Parse command line options (stop option parsing at first positional argument or --)
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --cover)
            GENERATE_COVERSHEET=true
            shift
            ;;
        --nocover)
            GENERATE_COVERSHEET=false
            shift
            ;;
        --from)
            [[ $# -ge 2 ]] || { echo "ERROR: --from requires an argument" >&2; exit 1; }
            CALLERID="$2"
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        --)
            shift
            ARGS+=("$@")
            break
            ;;
        -*)
            echo "ERROR: Unknown option $1" >&2
            usage 1
            ;;
        *)
            ARGS+=("$@")
            break
            ;;
    esac
done

# Restore positional arguments
set -- "${ARGS[@]}"

[[ $# -ge 2 ]] || usage 1
DEST="$1"
PDF="$2"
FAX_SUBJECT="${3:-Document Transmission}"
FAX_MESSAGE="${4:-Please find the attached document.}"
FAX_PRIORITY="${5:-$FAX_PRIORITY}"

if [[ ! -f "$PDF" || ! -r "$PDF" ]]; then
  echo "ERROR: PDF not found or not readable: $PDF" >&2
  exit 2
fi

if [[ $EUID -ne 0 ]] && [[ ! -w "$SPOOL_DIR" ]]; then
  echo "ERROR: Insufficient permissions to access Asterisk spool ($SPOOL_DIR). Please run with sudo." >&2
  exit 3
fi

if ! command -v asterisk >/dev/null 2>&1; then
  echo "ERROR: The 'asterisk' command was not found in your PATH." >&2
  exit 3
fi

if ! command -v gs >/dev/null 2>&1; then
  echo "ERROR: Ghostscript (gs) is not installed. Please install it." >&2
  exit 4
fi

if command -v magick >/dev/null 2>&1; then
  MAGICK_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
  MAGICK_CMD="convert"
else
  echo "ERROR: ImageMagick ('magick' or 'convert') is not installed. Please install it." >&2
  exit 4
fi

FAX_MOD_OUT=$(asterisk -rx "module show like res_fax" 2>&1 || true)
if ! grep -q "res_fax.so" <<< "$FAX_MOD_OUT"; then
  echo "ERROR: The res_fax.so module is not loaded in Asterisk (or Asterisk CLI is inaccessible)." >&2
  exit 5
fi
if ! grep -q "res_fax_spandsp.so" <<< "$FAX_MOD_OUT"; then
  echo "ERROR: The res_fax_spandsp.so module is not loaded in Asterisk." >&2
  exit 5
fi

# Parse CALLERID to extract name and number for header
if [[ $CALLERID =~ ^(.+)[[:space:]]*\<(\+?[0-9]+)\>$ ]]; then
  SENDER_NAME="${BASH_REMATCH[1]}"
  SENDER_PHONE="${BASH_REMATCH[2]}"
else
  SENDER_NAME="$CALLERID"
  SENDER_PHONE=""
fi
SENDER_NAME="${SENDER_NAME%"${SENDER_NAME##*[![:space:]]}"}"

# Parse DEST to extract recipient name and number (supporting "Name <phone>" or raw phone)
if [[ $DEST =~ ^(.+)[[:space:]]*\<([^>]+)\>$ ]]; then
  RECIPIENT_NAME="${BASH_REMATCH[1]}"
  RAW_DEST_PHONE="${BASH_REMATCH[2]}"
else
  RECIPIENT_NAME=""
  RAW_DEST_PHONE="$DEST"
fi

# Trim trailing whitespace from RECIPIENT_NAME if present
RECIPIENT_NAME="${RECIPIENT_NAME%"${RECIPIENT_NAME##*[![:space:]]}"}"

# Normalize phone number: strip spaces, dashes, dots, and parentheses
CLEAN_DEST_PHONE=$(printf '%s' "$RAW_DEST_PHONE" | tr -d '[:space:]().-')
if [[ ! $CLEAN_DEST_PHONE =~ ^\+?[0-9]{7,15}$ ]]; then
  echo "ERROR: Invalid destination phone number: '$RAW_DEST_PHONE' (parsed from '$DEST')" >&2
  exit 2
fi

# Preserve human-friendly number for headers/coversheet; strip leading '+' for PJSIP dial string
DEST_DISPLAY="$CLEAN_DEST_PHONE"
DEST_DIAL="${CLEAN_DEST_PHONE#+}"

# --- Main Script Logic ---

# Create a private per-run working directory with automatic trap cleanup
WORK_DIR=$(mktemp -d /tmp/fax-work.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

# Sanitize PDF basename (replace commas/newlines/unsafe chars so Asterisk Data: line cannot break)
RAW_BASENAME="$(basename "$PDF")"
SAFE_BASENAME=$(printf '%s' "${RAW_BASENAME%.*}" | tr '\r\n,' '___' | tr -cd 'A-Za-z0-9._ -')
[[ -n "$SAFE_BASENAME" ]] || SAFE_BASENAME="document"

STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TIFF="/tmp/fax-${STAMP}-${SAFE_BASENAME}.tiff"

mkdir -p "$STAGE_DIR"
CALL_FILENAME="faxcall-${STAMP}.call"
STAGE_CALL_FILE="${STAGE_DIR}/${CALL_FILENAME}"
FINAL_CALL_FILE="${SPOOL_DIR}/${CALL_FILENAME}"

# Convert PDF pages into 612x765pt (1728x2082px at 204x196 DPI) so stamp_header can
# bottom-align each page into 1728x2156px with a dedicated 74px white top header band.
echo "Converting PDF to fax-ready TIFF with headers..."

TEMP_PREFIX="${WORK_DIR}/page"
gs -dSAFER -dBATCH -dNOPAUSE \
   -sDEVICE=tiffg4 \
   -r204x196 \
   -dGridFitTT=2 -dAlignToPixels=1 \
   -dDEVICEWIDTHPOINTS=612 -dDEVICEHEIGHTPOINTS=765 \
   -dFIXEDMEDIA \
   -dPDFFitPage \
   -dUseCropBox \
   -sOutputFile="${TEMP_PREFIX}_%04d.tiff" \
   "$PDF"

shopt -s nullglob
PAGE_FILES=("${TEMP_PREFIX}"_*.tiff)
shopt -u nullglob

pdf_pages=${#PAGE_FILES[@]}
if (( pdf_pages == 0 )); then
  echo "ERROR: TIFF conversion failed (no pages produced)." >&2
  exit 6
fi
echo "Detected $pdf_pages page(s) in the document."

if [[ "$GENERATE_COVERSHEET" == true ]]; then
    total_pages=$((pdf_pages + 1))  # Add 1 for coversheet
    echo "Generating fax coversheet..."
else
    total_pages=$pdf_pages  # No coversheet
    echo "Skipping coversheet generation..."
fi

COVERSHEET_PS="${WORK_DIR}/coversheet.ps"
COVERSHEET_TIFF="${WORK_DIR}/coversheet.tiff"

# Get current date and time for fax header
CURRENT_DATE=$(date "+%Y-%m-%d %H:%M")

# Build sender information string for page headers
SENDER_INFO=""
if [[ -n "$SENDER_NAME" ]]; then
    SENDER_INFO=$(truncate_str "$SENDER_NAME" 28)
fi
if [[ -n "$SENDER_PHONE" ]]; then
    if [[ -n "$SENDER_INFO" ]]; then
        SENDER_INFO="$SENDER_INFO ($SENDER_PHONE)"
    else
        SENDER_INFO="($SENDER_PHONE)"
    fi
fi

if [[ "$GENERATE_COVERSHEET" == true ]]; then
    # Generate coversheet with correct page count
    generate_coversheet "$COVERSHEET_PS" "$total_pages" "$SENDER_NAME" "$SENDER_PHONE" "$RECIPIENT_NAME" "$DEST_DISPLAY" "$FAX_SUBJECT" "$FAX_MESSAGE" "$FAX_PRIORITY"

    # Convert coversheet to TIFF (full 612x792pt letter height; top border is already lowered)
    gs -dSAFER -dBATCH -dNOPAUSE \
       -sDEVICE=tiffg4 \
       -r204x196 \
       -sPAPERSIZE=letter \
       -dFIXEDMEDIA \
       -sOutputFile="$COVERSHEET_TIFF" \
       "$COVERSHEET_PS"

    stamp_header "$COVERSHEET_TIFF" 1 "$total_pages" false
fi

# Add fax header (with reserved 74px top banner) to each PDF page TIFF
for tiff_file in "${PAGE_FILES[@]}"; do
    PAGE_NUM=$(basename "$tiff_file" | sed -n 's/.*_\([0-9]\+\)\.tiff/\1/p')
    PAGE_NUM=$((10#$PAGE_NUM))  # Convert to decimal

    if [[ "$GENERATE_COVERSHEET" == true ]]; then
        DISPLAY_PAGE_NUM=$((PAGE_NUM + 1))
    else
        DISPLAY_PAGE_NUM=$PAGE_NUM
    fi

    stamp_header "$tiff_file" "$DISPLAY_PAGE_NUM" "$total_pages" true
done

# Combine files into a single multi-page Group4 TIFF with min-is-white polarity
if [[ "$GENERATE_COVERSHEET" == true ]]; then
    "$MAGICK_CMD" "$COVERSHEET_TIFF" "${PAGE_FILES[@]}" \
        -density 204x196 -units PixelsPerInch \
        -type Bilevel -depth 1 -compress Group4 \
        -define quantum:polarity=min-is-white \
        "$TIFF"
else
    "$MAGICK_CMD" "${PAGE_FILES[@]}" \
        -density 204x196 -units PixelsPerInch \
        -type Bilevel -depth 1 -compress Group4 \
        -define quantum:polarity=min-is-white \
        "$TIFF"
fi

if [[ ! -s "$TIFF" ]]; then
  echo "ERROR: Final TIFF creation failed." >&2
  exit 6
fi

# Verify final multi-page TIFF page count matches expected total_pages
actual_pages=$("$MAGICK_CMD" identify -format '%n\n' "$TIFF" 2>/dev/null | head -n 1 || echo 0)
if [[ "$actual_pages" != "$total_pages" ]]; then
  echo "ERROR: Final TIFF page count mismatch (expected $total_pages, got $actual_pages)." >&2
  rm -f "$TIFF"
  exit 6
fi

# Stage the call file on the same filesystem as SPOOL_DIR, then atomically rename into SPOOL_DIR
echo "Creating call file: $STAGE_CALL_FILE"
cat > "${STAGE_CALL_FILE}" << EOF
Channel: ${TECH}/${DEST_DIAL}@${TRUNK_NAME}
CallerID: ${CALLERID}
Application: SendFax
Data: ${TIFF},${EXTRA_FAX_OPTS}
MaxRetries: 3
RetryTime: 60
Archive: yes
EOF

echo "Submitting fax job to Asterisk..."
mv "${STAGE_CALL_FILE}" "${FINAL_CALL_FILE}"

echo "Fax job successfully submitted."
echo "Call file: ${FINAL_CALL_FILE}"
echo "TIFF file: $TIFF ($total_pages page(s))"
echo ""
echo "=== Monitoring Options ==="
echo "1. Real-time console: sudo asterisk -rvvv"
echo "2. Check fax logs:    sudo tail -f /var/log/asterisk/full | grep -i fax"
echo "3. Active spool:      ls -la ${FINAL_CALL_FILE}"
echo "4. Archived result:   sudo cat ${DONE_DIR}/${CALL_FILENAME}"
echo ""
echo "=== Status Indicators ==="
echo "- Call file moved to ${DONE_DIR}/ = call attempts finished"
echo "- 'Status: Completed' in archived call file = call connected (check logs for FAXSTATUS=SUCCESS)"
echo "- 'Status: Expired' in archived call file = max retries exceeded without answer"

# Automatically delete the rendered TIFF after 60 minutes (allows for 3 retries + slow multi-page transmissions)
(sleep 3600; rm -f "$TIFF") >/dev/null 2>&1 &

exit 0
