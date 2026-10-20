# sendfax.sh - Professional Asterisk Fax Transmission Script

A comprehensive Bash script for sending faxes through Asterisk with professional coversheets, multiple destination formats, and configurable options.

## Features

- 🎯 **Professional coversheets** with customizable content and priority levels
- 📞 **Multiple destination formats** - plain numbers, formatted numbers, or `"Name <phone>"`
- 🎨 **Enhanced text processing** - 75-character wrapping with an 18-line message box and `...more` overflow marker
- ⚙️ **Flexible coversheet control** - `--cover` / `--nocover` options
- 👤 **Configurable sender identity** - `--from` flag or `CALLERID` environment variable
- 📱 **Multi-page support** - handles complex documents with correct page numbering
- 🏷️ **Smart page headers** - sender, recipient, date, and page numbers on every page, stamped into a reserved top band so document content is never overwritten
- 🔒 **Robust text handling** - UTF-8 transliteration and PostScript escaping for names, subjects, and messages
- ⚡ **Atomic job submission** - call files are staged on the Asterisk filesystem and renamed into the spool atomically
- ✅ **Comprehensive validation** - phone-number normalization, dependency checks, and final page-count verification
- 🧹 **Automatic cleanup** - per-run temporary workspace removed on exit, even after errors
- 📋 **Multiple priority levels** - Normal, Urgent, High, Low
- 🌍 **International phone formats** supported

## Requirements

- **Asterisk** with `res_fax.so` **and** a fax technology module such as `res_fax_spandsp.so`
- **Ghostscript** (`gs`) for PDF-to-TIFF conversion
- **ImageMagick** (`magick` or `convert`) for header stamping
- **Bash 4+** and standard Unix tools (`fold`, `fmt`, `sed`, `tr`, `iconv` recommended)
- Permission to write to the Asterisk spool directory (usually `sudo`, or grant ACL access)

Tested with Asterisk 22, Ghostscript 10, and ImageMagick 7 on Debian 13.

## Installation

1. Download the script:

   ```sh
   wget https://raw.githubusercontent.com/zwangzw-zw/sendfax-asterisk/main/sendfax.sh
   chmod +x sendfax.sh
   ```

2. Configure the script by editing the configuration section:

   ```bash
   TECH="PJSIP"                              # Channel technology (PJSIP or SIP)
   TRUNK_NAME="your-trunk-name"              # SIP trunk/endpoint name
   CALLERID="${CALLERID:-Your Name <+15551234567>}"  # Sender identity
   EXTRA_FAX_OPTS="df"                       # SendFax options (d=debug, f=audio fallback)
   FAX_PRIORITY="Normal"                     # Default priority
   SPOOL_DIR="/var/spool/asterisk/outgoing"  # Asterisk outgoing spool
   STAGE_DIR="/var/spool/asterisk/tmp"       # Staging dir on the same filesystem
   DONE_DIR="/var/spool/asterisk/outgoing_done"  # Asterisk archive directory
   ```

3. Run it with sufficient privileges to write to the Asterisk spool:

   ```bash
   sudo ./sendfax.sh 5551234567 document.pdf
   ```

   Alternatively, grant your user write access with ACLs and run it directly:

   ```bash
   sudo setfacl -m u:$USER:rwx /var/spool/asterisk/tmp /var/spool/asterisk/outgoing
   sudo setfacl -d -m u:$USER:rwx /var/spool/asterisk/tmp /var/spool/asterisk/outgoing
   ```

## Usage

### Basic Syntax

```bash
./sendfax.sh [--cover|--nocover] [--from "Name <phone>"] [--] <destination> <input.pdf> [subject] [message] [priority]
```

### Options

- `--cover` - Generate a coversheet (default)
- `--nocover` - Skip coversheet generation
- `--from "Name <phone>"` - Override the sender CallerID for this transmission
- `--` - End of options; treat all remaining arguments as positional
- `-h, --help` - Show the help message

### Examples

#### Basic fax with coversheet

```bash
./sendfax.sh 5551234567 document.pdf
```

#### Named recipient with custom subject, message, and priority

```bash
./sendfax.sh --cover "John Smith <+15551234567>" document.pdf \
  "Important Contract" \
  "Please review and sign the attached contract. Contact me if you have questions." \
  "Urgent"
```

#### Send as a different sender identity

```bash
./sendfax.sh --from "Acme Legal <+15551234567>" 5551234567 document.pdf
```

#### Skip the coversheet for a simple transmission

```bash
./sendfax.sh --nocover 5551234567 document.pdf
```

#### International destination

```bash
./sendfax.sh "Marie Dubois <+33123456789>" document.pdf \
  "Monthly Report" \
  "Please find attached this month's summary report." \
  "Low"
```

## Destination Formats

### Plain Phone Numbers

- `5551234567`
- `+15551234567`
- `15551234567`

### Formatted Phone Numbers

Formatting characters are stripped before dialing:

- `(555) 123-4567`
- `555.123.4567`

### Named Recipients

- `"John Smith <+15551234567>"`
- `"Dr. Johnson <5551234567>"`
- `"Support Team <+18005551234>"`

The name is printed on the coversheet and in the page header; the number is normalized and used for the PJSIP dial string. A leading `+` is removed from the dial string for compatibility with common SIP providers.

## Priority Levels

- **Normal** - Standard delivery (default)
- **Urgent** - High-priority transmission
- **High** - Important document
- **Low** - Non-urgent delivery

The priority is printed on the coversheet. It does not alter the SIP call itself.

## Configuration

### Required Configuration

Edit the configuration section at the top of the script:

```bash
# --- Configuration (edit to match your system) --------------------------------
TECH="PJSIP"                              # Channel technology (PJSIP/SIP)
TRUNK_NAME="your-trunk-name"              # SIP trunk name from pjsip.conf
CALLERID="${CALLERID:-Your Name <+15551234567>}"  # Sender identity
EXTRA_FAX_OPTS="df"                       # SendFax options
FAX_PRIORITY="Normal"                     # Default priority level
SPOOL_DIR="/var/spool/asterisk/outgoing"  # Asterisk spool directory
STAGE_DIR="/var/spool/asterisk/tmp"       # Staging directory (same filesystem)
DONE_DIR="/var/spool/asterisk/outgoing_done"  # Archived call files
```

`CALLERID` can also be supplied at run time, which is useful for shared installations:

```bash
CALLERID="Billing Department <+15551234567>" ./sendfax.sh 5551234567 invoice.pdf
```

The `--from` option takes precedence over the environment variable for that run.

### SendFax Options

`EXTRA_FAX_OPTS` is passed to Asterisk's `SendFAX()` application:

- `d` - Enable FAX debugging
- `f` - Allow audio fallback FAX transfer on T.38-capable channels
- `F` - Force audio mode on T.38-capable channels
- `s` - Send progress Manager events
- `z` - Initiate a T.38 reinvite if the remote end does not

ECM is configured globally in `res_fax.conf` (`fax show settings`), not through these options.

### Asterisk Configuration Example

#### pjsip.conf (recommended)

```ini
[your-trunk-name]
type=endpoint
transport=transport-udp
context=outbound-fax
disallow=all
allow=ulaw
aors=your-trunk-aor

; T.38 settings (recommended for fax)
t38_udptl=yes
t38_udptl_ec=fec
t38_udptl_nat=yes
t38_udptl_maxdatagram=400
direct_media=no
force_rport=yes
rewrite_contact=yes
rtp_symmetric=yes

[your-trunk-aor]
type=aor
contact=sip:your-provider.example.com

[your-trunk-auth]
type=auth
auth_type=userpass
username=your-username
password=your-password
```

#### extensions.conf

```ini
[outbound-fax]
exten => _X.,1,NoOp(Outbound Fax)
 same => n,Dial(PJSIP/${EXTEN}@your-trunk-name,60)
 same => n,Hangup()
```

## How It Works

1. **Validation** - Checks the PDF, dependencies, Asterisk modules, and destination number.
2. **PDF conversion** - Ghostscript renders each page to a Group 4 TIFF at 204x196 DPI into a private temporary directory.
3. **Coversheet** - A PostScript coversheet is generated with Helvetica fonts, 15pt body leading, and 75-character message wrapping. All user text is transliterated to ASCII and escaped for PostScript.
4. **Header stamping** - Each PDF page is bottom-aligned into a 1728x2156 canvas, reserving a 74-pixel white band at the top. The `FROM | TO | date | PAGE` header is stamped into that band, so no document content is ever overwritten.
5. **Assembly** - Pages are combined into a single multi-page Group 4 TIFF with `min-is-white` polarity, and the page count is verified.
6. **Submission** - A `.call` file is written to the staging directory on the Asterisk filesystem and atomically renamed into `/var/spool/asterisk/outgoing`.

## Monitoring Fax Status

### Real-time Monitoring

```bash
# Watch the Asterisk console
sudo asterisk -rvvv

# Monitor fax logs
sudo tail -f /var/log/asterisk/full | grep -i fax
```

### Call File Status

With `Archive: yes`, Asterisk moves each processed call file to
`/var/spool/asterisk/outgoing_done/` and appends status lines:

```bash
sudo tail -n 8 /var/spool/asterisk/outgoing_done/faxcall-*.call
```

- **`Status: Completed`** - Asterisk finished processing the call file (check the logs for `FAXSTATUS=SUCCESS`)
- **`Status: Expired`** - Maximum retries were exceeded

### Fax Application Status

Look for these channel variables in the Asterisk log:

- `FAXSTATUS=SUCCESS` - Fax transmitted successfully
- `FAXSTATUS=FAILED` - Transmission failed
- `FAXERROR` - Reason for failure
- `FAXPAGES`, `FAXBITRATE`, `FAXRESOLUTION`, `FAXMODE` - Session details

## Advanced Features

### Text Processing

- **75-character line width** for proportional 12pt Helvetica text inside the 512pt message box
- **18-line message capacity** with word-aware wrapping and a hard-wrap fallback for long URLs
- **Overflow handling** with a `...more` indicator
- **UTF-8 transliteration** - accents and typographic punctuation are converted to ASCII
- **PostScript escaping** - `\`, `(`, and `)` are escaped so arbitrary text cannot break the coversheet

### Page Numbering

- **With coversheet**: the coversheet is page 1, PDF pages start at 2
- **Without coversheet**: PDF pages start at 1
- **Automatic adjustment** based on coversheet presence

### Page Headers

Each page includes a compact header in a reserved top band:

- Sender name and number
- Recipient name and number (truncated to fit)
- Transmission date and time
- Page number (`PAGE n/total`)

The header ink starts about 4.9 mm from the top edge, which clears the typical 4–5 mm non-printable margin of office fax machines and multifunction printers. The reserved band keeps headers away from PDF content.

### Reliability

- Atomic call-file submission (staged and renamed on the same filesystem)
- Private per-run temporary directory with `trap` cleanup
- Final TIFF page-count verification before submission
- Clear, early errors for missing dependencies, missing fax modules, and permission problems
- Automatic deletion of the rendered TIFF 60 minutes after submission (allows for retries)

## Troubleshooting

### "Insufficient permissions to access Asterisk spool"

Run the script with `sudo`, or grant your user ACL access to the spool directories as shown in the Installation section.

### "The res_fax.so module is not loaded"

Load the module in Asterisk:

```bash
sudo asterisk -rx "module load res_fax.so"
```

Also verify that a fax technology module is available:

```bash
sudo asterisk -rx "module show like res_fax"
```

You should see both `res_fax.so` and a technology module such as `res_fax_spandsp.so`.

### "The res_fax_spandsp.so module is not loaded"

Install the Asterisk fax/Spandsp package for your distribution (for example, `asterisk-res-fax-spandsp` on Debian/Ubuntu) and load it:

```bash
sudo asterisk -rx "module load res_fax_spandsp.so"
```

### Coversheet text is missing accents or special characters

The script transliterates UTF-8 to ASCII because the built-in PostScript fonts use StandardEncoding. Characters that cannot be transliterated are omitted. For full Unicode support, a custom embedded font would be required.

### Long names or subjects are truncated

Names on the coversheet are capped at 34 characters, page-header names at 28 characters, and subjects at 64 characters. This prevents text from crossing columns or the page margin.

### Fax arrives but the top of the page looks shifted

The script reserves a 74-pixel header band and scales PDF pages to fit the remaining area (about 96.6% for US Letter). This guarantees that top-edge document content is not overwritten by the header. If exact 1:1 scaling is required, use `--nocover` and adjust the layout in the script.

### Log Analysis

```bash
# Recent fax attempts
grep "SendFax" /var/log/asterisk/full | tail -20

# Fax errors
grep -i "error\|fail" /var/log/asterisk/full | grep -i fax | tail -10

# Fax statistics
sudo asterisk -rx "fax show stats"
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details and [CHANGELOG.md](CHANGELOG.md) for the version history.

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License - see the [LICENSE](LICENSE) file for details.

**Key Points:**
- ✅ Free for personal, educational, and non-profit use
- ✅ Modify and redistribute with attribution
- ✅ **Must share source code** of any modifications under same license
- ❌ Commercial use requires separate licensing
- 🔗 Full license: https://creativecommons.org/licenses/by-nc-sa/4.0/

## Support

- 📧 **Issues**: [GitHub Issues](https://github.com/zwangzw-zw/sendfax-asterisk/issues)
- 📖 **Documentation**: [Wiki](https://github.com/zwangzw-zw/sendfax-asterisk/wiki)
