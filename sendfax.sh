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
    local recipient="$1"
    local fax_number="$2"
    local pages="$3"
    local output_file="$4"

    # Ghostscript command to generate the coversheet
    gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
        -sOutputFile="$output_file" \
        -dPDFFitPage \
        -c "<</Title (Fax Cover Sheet) /Author (Asterisk) /Subject (Fax) /Keywords (fax cover sheet)>> setpagedevice" \
        -f "$COVERSHEET_TEMPLATE" \
        -c "($recipient) 12 selectfont 100 700 moveto (To:) show" \
        -c "($fax_number) 12 selectfont 100 650 moveto (Fax Number:) show" \
        -c "($pages) 12 selectfont 100 600 moveto (Pages:) show" \
        -f -
}

# Main script logic
# ...rest of the script copied from sendfax-github.sh...
