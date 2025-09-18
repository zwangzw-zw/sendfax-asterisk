#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (edit to match your system) --------------------------------
# Your channel technology (PJSIP is recommended)
TECH="PJSIP"
# The name of your trunk in pjsip.conf or sip.conf
TRUNK_NAME="your-trunk-name"
# The Caller ID you want to send
CALLERID="Your Name <+15551234567>"
# Extra options for the SendFax application (d=ECM enabled)
EXTRA_FAX_OPTS="df"
# Default fax priority (can be overridden with command line option)
FAX_PRIORITY="Normal"

# The directory Asterisk monitors for new call files
SPOOL_DIR="/var/spool/asterisk/outgoing"
# ------------------------------------------------------------------------------

# Function to generate fax coversheet using Ghostscript
generate_coversheet() {
    local coversheet_ps="$1"
    local current_date="$2"
    local total_pages="$3"
    local sender_name="$4"
    local sender_phone="$5"
    local recipient_name="$6"
    local recipient_phone="$7"
    local fax_subject="$8"
    local fax_message="$9"
    local fax_priority="${10}"

    # Handle long messages using fold for proper word wrapping
    # Message box spans from y=467 to y=180 (287 points) - EXPANDED!
    # With 12pt font and ~15pt line spacing, we can fit about 18 lines
    # Message box width: 512 points, optimal line length: ~85 characters
    local wrapped_lines
    if command -v fold >/dev/null 2>&1; then
        wrapped_lines=$(echo "$fax_message" | fold -s -w 85)
    elif command -v fmt >/dev/null 2>&1; then
        wrapped_lines=$(echo "$fax_message" | fmt -w 85)
    else
        # Fallback to simple character splitting if neither tool is available
        if [ ${#fax_message} -le 85 ]; then
            wrapped_lines="$fax_message"
        else
            wrapped_lines="${fax_message:0:85}
${fax_message:85:85}"
        fi
    fi
    
    # Count total lines and prepare message lines (up to 18 lines max - EXPANDED!)
    local line_count=$(echo "$wrapped_lines" | wc -l)
    local max_lines=18
    local message_lines=()
    local show_more=false
    
    if [ "$line_count" -le "$max_lines" ]; then
        # Show all lines if they fit
        for i in $(seq 1 $line_count); do
            message_lines[$(($i-1))]=$(echo "$wrapped_lines" | sed -n "${i}p")
        done
    else
        # Show first (max_lines-1) lines plus "...more"
        for i in $(seq 1 $(($max_lines-1))); do
            message_lines[$(($i-1))]=$(echo "$wrapped_lines" | sed -n "${i}p")
        done
        message_lines[$(($max_lines-1))]="...more"
        show_more=true
    fi

    cat > "$coversheet_ps" << EOF
%!PS-Adobe-3.0
%%BoundingBox: 0 0 612 792
%%Title: Fax Cover Sheet
%%Creator: sendfax.sh

% Define fonts
/TitleFont { /Times-Bold findfont 20 scalefont setfont } def
/HeaderFont { /Times-Bold findfont 14 scalefont setfont } def
/BodyFont { /Times-Roman findfont 12 scalefont setfont } def
/SmallFont { /Times-Roman findfont 10 scalefont setfont } def

% Colors and line width
1 setlinewidth
0 setgray

% Top decorative border
50 770 moveto 562 770 lineto
50 765 moveto 562 765 lineto
stroke

% Main title (moved down ~1cm = 28pts)
TitleFont
306 717 moveto
(FACSIMILE TRANSMISSION) dup stringwidth pop 2 div neg 0 rmoveto show

% Decorative line after title (transmission header will be added by ImageMagick)
50 692 moveto 562 692 lineto stroke

% Professional sections with boxes
HeaderFont

% From section (no border)
HeaderFont
50 652 moveto (FROM:) show
BodyFont
55 637 moveto ($sender_name) show
55 627 moveto ($sender_phone) show

% To section (no border)
HeaderFont
317 652 moveto (TO:) show
BodyFont
322 637 moveto ($recipient_name) show
322 627 moveto ($recipient_phone) show

% Pages info (no border)
HeaderFont
50 597 moveto (PAGES:) show
BodyFont
55 582 moveto (Total Pages: $total_pages) show
55 572 moveto (Including cover sheet) show

% Priority (no border)
HeaderFont
317 597 moveto (PRIORITY:) show
BodyFont
322 582 moveto ($fax_priority) show

% Subject section (moved closer to MESSAGE)
HeaderFont
50 520 moveto (SUBJECT:) show
BodyFont
130 520 moveto ($fax_subject) show

% Message section
HeaderFont
50 497 moveto (MESSAGE:) show

% Message box - EXPANDED from 135pts to 287pts height!
50 467 moveto 562 467 lineto 562 180 lineto 50 180 lineto closepath stroke
BodyFont

EOF

    # Generate message lines dynamically
    local y_pos=452
    for i in "${!message_lines[@]}"; do
        if [ -n "${message_lines[$i]}" ]; then
            cat >> "$coversheet_ps" << EOF
% Message line $(($i + 1))
55 $y_pos moveto (${message_lines[$i]}) show
EOF
            y_pos=$(($y_pos - 15))  # Move down 15 points for next line
        fi
    done

    cat >> "$coversheet_ps" << EOF

% Professional footer section
50 140 moveto 562 140 lineto stroke
50 135 moveto 562 135 lineto stroke

SmallFont
50 125 moveto (CONFIDENTIALITY NOTICE:) show
50 110 moveto (This facsimile transmission contains confidential information intended only) show
50 100 moveto (for the use of the individual or entity named above. If you are not the intended) show
50 90 moveto (recipient, you are hereby notified that any disclosure, copying, distribution,) show
50 80 moveto (or use of this information is strictly prohibited.) show

% Bottom decorative elements
50 50 moveto 562 50 lineto
50 45 moveto 562 45 lineto
stroke

showpage
EOF
}

usage() {
  echo "Usage: $0 [--cover|--nocover] <destination> <input.pdf> [subject] [message] [priority]"
  echo "Options:"
  echo "  --cover     Generate coversheet (default)"
  echo "  --nocover   Skip coversheet generation"
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
  exit 1
}


# --- Input Validation and System Checks ---

# Default coversheet setting
GENERATE_COVERSHEET=true

# Parse command line arguments
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
        -h|--help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option $1" >&2
            usage
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${ARGS[@]}"

[[ $# -ge 2 ]] || usage
DEST="$1"
PDF="$2"
FAX_SUBJECT="${3:-Document Transmission}"
FAX_MESSAGE="${4:-Please find the attached document.}"
FAX_PRIORITY="${5:-$FAX_PRIORITY}"

if [[ ! -f "$PDF" ]]; then
  echo "ERROR: PDF not found: $PDF" >&2
  exit 2
fi

if ! command -v asterisk >/dev/null 2>&1; then
  echo "ERROR: The 'asterisk' command was not found in your PATH." >&2
  exit 3
fi

if ! command -v gs >/dev/null 2>&1; then
  echo "ERROR: Ghostscript (gs) is not installed. Please install it." >&2
  exit 4
fi

if ! asterisk -rx "module show like res_fax.so" | grep -q "res_fax.so"; then
  echo "ERROR: The res_fax.so module is not loaded in Asterisk." >&2
  exit 5
fi

# --- Main Script Logic ---

# Create a unique filename for the temporary TIFF file
BASENAME="$(basename "$PDF")"
STAMP="$(date +%Y%m%d-%H%M%S)"
TIFF="/tmp/fax-${STAMP}-${BASENAME%.*}.tiff"
CALL_FILE="/tmp/faxcall-${STAMP}.call"

# Convert PDF to fax-ready TIFF using comprehensive approach
echo "Converting PDF to fax-ready TIFF with headers..."

# First convert to temporary individual TIFF files
TEMP_PREFIX="/tmp/fax-temp-${STAMP}"
gs -dSAFER -dBATCH -dNOPAUSE \
   -sDEVICE=tiffg4 \
   -r204x196 \
   -sPAPERSIZE=letter \
   -dFIXEDMEDIA \
   -dPDFFitPage \
   -dUseCropBox \
   -sOutputFile="${TEMP_PREFIX}_%03d.tiff" \
   "$PDF"

if [[ ! -f "${TEMP_PREFIX}_001.tiff" ]]; then
  echo "ERROR: TIFF conversion failed." >&2
  exit 6
fi

# Count total pages (PDF pages only)
pdf_pages=$(ls "${TEMP_PREFIX}"_*.tiff 2>/dev/null | wc -l)
echo "Detected $pdf_pages page(s) in the document."

if $GENERATE_COVERSHEET; then
    total_pages=$((pdf_pages + 1))  # Add 1 for coversheet
    echo "Generating fax coversheet..."
else
    total_pages=$pdf_pages  # No coversheet
    echo "Skipping coversheet generation..."
fi

COVERSHEET_PS="/tmp/fax-coversheet-${STAMP}.ps"
COVERSHEET_TIFF="/tmp/fax-coversheet-${STAMP}.tiff"

# Parse CALLERID to extract name and number for header
if [[ $CALLERID =~ ^(.+)\ \<([0-9+]+)\>$ ]]; then
  SENDER_NAME="${BASH_REMATCH[1]}"
  SENDER_PHONE="${BASH_REMATCH[2]}"
else
  SENDER_NAME="$CALLERID"
  SENDER_PHONE=""
fi

# Parse DEST to extract recipient name and number (supporting "Name <+phone>" format)
if [[ $DEST =~ ^(.+)\ \<(\+?[0-9]+)\>$ ]]; then
  RECIPIENT_NAME="${BASH_REMATCH[1]}"
  DEST_PHONE="${BASH_REMATCH[2]}"
else
  RECIPIENT_NAME=""
  DEST_PHONE="$DEST"
fi

# Get current date and time for fax header
CURRENT_DATE=$(date "+%Y-%m-%d %H:%M")

if $GENERATE_COVERSHEET; then
    # Generate coversheet with correct page count
    generate_coversheet "$COVERSHEET_PS" "$CURRENT_DATE" "$total_pages" "$SENDER_NAME" "$SENDER_PHONE" "$RECIPIENT_NAME" "$DEST_PHONE" "$FAX_SUBJECT" "$FAX_MESSAGE" "$FAX_PRIORITY"

    # Convert coversheet to TIFF
    gs -dSAFER -dBATCH -dNOPAUSE \
       -sDEVICE=tiffg4 \
       -r204x196 \
       -sPAPERSIZE=letter \
       -dFIXEDMEDIA \
       -sOutputFile="$COVERSHEET_TIFF" \
       "$COVERSHEET_PS"
fi

# Build sender information
SENDER_INFO=""
if [ -n "$SENDER_NAME" ]; then
    SENDER_INFO="$SENDER_NAME"
fi

if [ -n "$SENDER_PHONE" ]; then
    if [ -n "$SENDER_INFO" ]; then
        SENDER_INFO="$SENDER_INFO ($SENDER_PHONE)"
    else
        SENDER_INFO="($SENDER_PHONE)"
    fi
fi

# Add fax header to each TIFF file
for tiff_file in "${TEMP_PREFIX}"_*.tiff; do
    if [ -f "$tiff_file" ]; then
        # Extract page number from filename
        PAGE_NUM=$(echo "$tiff_file" | sed -n 's/.*_\([0-9]\+\)\.tiff/\1/p')
        PAGE_NUM=$((10#$PAGE_NUM))  # Convert to decimal

        # Adjust page number to account for coversheet
        if $GENERATE_COVERSHEET; then
            # Coversheet = page 1, PDF pages start at 2
            DISPLAY_PAGE_NUM=$((PAGE_NUM + 1))
        else
            # No coversheet, PDF pages start at 1
            DISPLAY_PAGE_NUM=$PAGE_NUM
        fi

        # Build complete header
        HEADER_TEXT=""
        if [ -n "$SENDER_INFO" ]; then
            HEADER_TEXT="FROM: $SENDER_INFO"
        fi

        if [ -n "$DEST_PHONE" ]; then
            if [ -n "$HEADER_TEXT" ]; then
                if [ -n "$RECIPIENT_NAME" ]; then
                    HEADER_TEXT="$HEADER_TEXT | TO: $RECIPIENT_NAME ($DEST_PHONE)"
                else
                    HEADER_TEXT="$HEADER_TEXT | TO: $DEST_PHONE"
                fi
            else
                if [ -n "$RECIPIENT_NAME" ]; then
                    HEADER_TEXT="TO: $RECIPIENT_NAME ($DEST_PHONE)"
                else
                    HEADER_TEXT="TO: $DEST_PHONE"
                fi
            fi
        fi

        if [ -n "$HEADER_TEXT" ]; then
            HEADER_TEXT="$HEADER_TEXT | $CURRENT_DATE | PAGE $DISPLAY_PAGE_NUM/$total_pages"
        else
            HEADER_TEXT="$CURRENT_DATE | PAGE $DISPLAY_PAGE_NUM/$total_pages"
        fi

        # Create temporary file with header
        TEMP_FILE=$(mktemp)

        # Add header using ImageMagick with system default font
        if command -v magick &> /dev/null; then
            magick "$tiff_file" \
                -gravity North \
                -pointsize 30 \
                -fill black \
                -annotate +0+25 "$HEADER_TEXT" \
                -compress Group4 \
                "$TEMP_FILE" && mv "$TEMP_FILE" "$tiff_file" || echo "Header failed for $tiff_file"
        elif command -v convert &> /dev/null; then
            convert "$tiff_file" \
                -gravity North \
                -pointsize 30 \
                -fill black \
                -annotate +0+25 "$HEADER_TEXT" \
                -compress Group4 \
                "$TEMP_FILE" && mv "$TEMP_FILE" "$tiff_file" || echo "Header failed for $tiff_file"
        else
            echo "Warning: ImageMagick not found. No header added to $tiff_file"
        fi
    fi
done

# Add fax header to coversheet if generating one
if $GENERATE_COVERSHEET; then
    COVERSHEET_HEADER_TEXT=""
    if [ -n "$SENDER_INFO" ]; then
        COVERSHEET_HEADER_TEXT="FROM: $SENDER_INFO"
    fi

    if [ -n "$DEST_PHONE" ]; then
        if [ -n "$COVERSHEET_HEADER_TEXT" ]; then
            if [ -n "$RECIPIENT_NAME" ]; then
                COVERSHEET_HEADER_TEXT="$COVERSHEET_HEADER_TEXT | TO: $RECIPIENT_NAME ($DEST_PHONE)"
            else
                COVERSHEET_HEADER_TEXT="$COVERSHEET_HEADER_TEXT | TO: $DEST_PHONE"
            fi
        else
            if [ -n "$RECIPIENT_NAME" ]; then
                COVERSHEET_HEADER_TEXT="TO: $RECIPIENT_NAME ($DEST_PHONE)"
            else
                COVERSHEET_HEADER_TEXT="TO: $DEST_PHONE"
            fi
        fi
    fi

    if [ -n "$COVERSHEET_HEADER_TEXT" ]; then
        COVERSHEET_HEADER_TEXT="$COVERSHEET_HEADER_TEXT | $CURRENT_DATE | PAGE 1/$total_pages"
    else
        COVERSHEET_HEADER_TEXT="$CURRENT_DATE | PAGE 1/$total_pages"
    fi

    # Add header to coversheet
    TEMP_COVERSHEET=$(mktemp)
    if command -v magick &> /dev/null; then
        magick "$COVERSHEET_TIFF" \
            -gravity North \
            -pointsize 30 \
            -fill black \
            -annotate +0+25 "$COVERSHEET_HEADER_TEXT" \
            -compress Group4 \
            "$TEMP_COVERSHEET" && mv "$TEMP_COVERSHEET" "$COVERSHEET_TIFF" || echo "Header failed for coversheet"
    elif command -v convert &> /dev/null; then
        convert "$COVERSHEET_TIFF" \
            -gravity North \
            -pointsize 30 \
            -fill black \
            -annotate +0+25 "$COVERSHEET_HEADER_TEXT" \
            -compress Group4 \
            "$TEMP_COVERSHEET" && mv "$TEMP_COVERSHEET" "$COVERSHEET_TIFF" || echo "Header failed for coversheet"
    fi
fi

# Combine files into a single multi-page TIFF
if $GENERATE_COVERSHEET; then
    # Combine coversheet and all pages
    if command -v magick &> /dev/null; then
        magick "$COVERSHEET_TIFF" "${TEMP_PREFIX}"_*.tiff -compress Group4 "$TIFF"
    elif command -v convert &> /dev/null; then
        convert "$COVERSHEET_TIFF" "${TEMP_PREFIX}"_*.tiff -compress Group4 "$TIFF"
    else
        echo "Warning: ImageMagick not found. Cannot combine pages into single TIFF"
        # Just use coversheet as fallback
        cp "$COVERSHEET_TIFF" "$TIFF" 2>/dev/null || true
    fi
else
    # Just use PDF pages without coversheet
    if command -v magick &> /dev/null; then
        magick "${TEMP_PREFIX}"_*.tiff -compress Group4 "$TIFF"
    elif command -v convert &> /dev/null; then
        convert "${TEMP_PREFIX}"_*.tiff -compress Group4 "$TIFF"
    else
        echo "Warning: ImageMagick not found. Cannot combine pages into single TIFF"
        # Use first page as fallback
        cp "${TEMP_PREFIX}_001.tiff" "$TIFF" 2>/dev/null || true
    fi
fi

# Clean up temporary files
rm -f "${TEMP_PREFIX}"_*.tiff
if $GENERATE_COVERSHEET; then
    rm -f "$COVERSHEET_PS" "$COVERSHEET_TIFF"
fi

if [[ ! -f "$TIFF" ]]; then
  echo "ERROR: Final TIFF creation failed." >&2
  exit 6
fi

# Create the call file in /tmp
echo "Creating call file: $CALL_FILE"
cat > "${CALL_FILE}" << EOF
Channel: ${TECH}/${DEST_PHONE}@${TRUNK_NAME}
CallerID: ${CALLERID}
Application: SendFax
Data: ${TIFF},${EXTRA_FAX_OPTS}
MaxRetries: 2
RetryTime: 60
Archive: yes
EOF

# Move the call file to the Asterisk spool directory to trigger the call
echo "Submitting fax job to Asterisk..."
mv "${CALL_FILE}" "${SPOOL_DIR}/"

echo "Fax job successfully submitted."
echo "Call file: ${SPOOL_DIR}/$(basename "$CALL_FILE")"
echo "TIFF file: $TIFF"
echo ""
echo "=== Monitoring Options ==="
echo "1. Real-time console: sudo asterisk -rvvv"
echo "2. Check logs: sudo tail -f /var/log/asterisk/full | grep -i fax"
echo "3. Call file status: ls -la ${SPOOL_DIR}/$(basename "$CALL_FILE")*"
echo ""
echo "=== Status Indicators ==="
echo "- Call file deleted = call attempted"
echo "- FAXSTATUS=SUCCESS = successful transmission"
echo "- FAXSTATUS=FAILED = transmission failed"
echo "- Status: Expired = max retries exceeded"

# Optional: Uncomment the line below to automatically delete the TIFF
# file after 15 minutes to clean up the /tmp directory.
# (sleep 900; rm -f "$TIFF") >/dev/null 2>&1 & disown

exit 0