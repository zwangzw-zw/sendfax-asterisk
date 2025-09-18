# sendfax.sh - Professional Asterisk Fax Transmission Script

A comprehensive bash script for sending faxes through Asterisk with professional coversheets, multiple destination formats, and configurable options.

## Features

- 🎯 **Professional coversheets** with customizable content and priority levels
- 📞 **Multiple destination formats** - plain numbers or "Name <phone>" format
- 🎨 **Enhanced text processing** - 85-character width with 18-line message capacity
- ⚙️ **Flexible coversheet control** - `--cover` / `--nocover` options
- 📱 **Multi-page support** - handles complex documents with proper page numbering
- 🏷️ **Smart header generation** - automatic sender/recipient/date/page information
- 🔧 **Comprehensive error handling** and status reporting
- 📋 **Multiple priority levels** - Normal, Urgent, High, Low
- 🌍 **International phone formats** supported

## Requirements

- **Asterisk** with `res_fax.so` module loaded
- **Ghostscript** (`gs`) for PDF/TIFF conversion
- **ImageMagick** (`magick` or `convert`) for header generation
- **Standard Unix tools** (`fold`, `fmt`, `sed`, `awk`)

## Installation

1. Download the script:

  ```sh
  wget https://raw.githubusercontent.com/zwangzw-zw/sendfax-asterisk/main/sendfax.sh
  chmod +x sendfax.sh
  ```

2. Configure the script by editing the configuration section:
   ```bash
   # Edit configuration variables
   TECH="PJSIP"                              # Your channel technology
   TRUNK_NAME="your-trunk-name"              # Your SIP trunk name
   CALLERID="Your Name <+15551234567>"       # Your caller ID
   EXTRA_FAX_OPTS="df"                       # Fax options (d=ECM enabled)
   SPOOL_DIR="/var/spool/asterisk/outgoing"  # Asterisk spool directory
   ```

## Usage

### Basic Syntax
```bash
./sendfax.sh [--cover|--nocover] <destination> <input.pdf> [subject] [message] [priority]
```

### Options
- `--cover` - Generate coversheet (default)
- `--nocover` - Skip coversheet generation
- `-h, --help` - Show help message

### Examples

#### Basic fax with coversheet (default)
```bash
./sendfax.sh 5551234567 document.pdf
```

#### Named recipient with custom message
```bash
./sendfax.sh --cover "John Smith <+15551234567>" document.pdf \
  "Important Contract" \
  "Please review and sign the attached contract. Contact me if you have questions." \
  "Urgent"
```

#### Skip coversheet for simple transmission
```bash
./sendfax.sh --nocover 5551234567 document.pdf
```

#### International format with low priority
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

### Named Recipients
- `"John Smith <+15551234567>"`
- `"Dr. Johnson <5551234567>"`
- `"Support Team <+18005551234>"`

## Priority Levels

- **Normal** - Standard delivery (default)
- **Urgent** - High-priority transmission
- **High** - Important document
- **Low** - Non-urgent delivery

## Configuration

### Required Configuration
Edit the configuration section at the top of the script:

```bash
# --- Configuration (edit to match your system) --------------------------------
TECH="PJSIP"                              # Channel technology (PJSIP/SIP)
TRUNK_NAME="your-trunk-name"              # SIP trunk name from config
CALLERID="Your Name <+15551234567>"       # Your caller ID information
EXTRA_FAX_OPTS="df"                       # SendFax options
FAX_PRIORITY="Normal"                     # Default priority level
SPOOL_DIR="/var/spool/asterisk/outgoing"  # Asterisk spool directory
```

### Asterisk Configuration Example

#### pjsip.conf (recommended)
```ini
[your-trunk-name]
type=endpoint
context=outbound-fax
disallow=all
allow=alaw
allow=ulaw
outbound_auth=your-trunk-name
aors=your-trunk-name

[your-trunk-name]
type=aor
contact=sip:your-provider.com

[your-trunk-name]
type=auth
auth_type=userpass
username=your-username
password=your-password
```

#### extensions.conf
```ini
[outbound-fax]
exten => _X.,1,NoOp(Outbound Fax)
exten => _X.,n,Dial(PJSIP/${EXTEN}@your-trunk-name)
```

## Monitoring Fax Status

### Real-time Monitoring
```bash
# Watch Asterisk console
sudo asterisk -rvvv

# Monitor fax logs
sudo tail -f /var/log/asterisk/full | grep -i fax

# Check call file status
ls -la /var/spool/asterisk/outgoing/faxcall-*
```

### Status Indicators
- **Call file deleted** = Call was attempted by Asterisk
- **FAXSTATUS=SUCCESS** = Successful transmission
- **FAXSTATUS=FAILED** = Transmission failed
- **Status: Expired** = Maximum retries exceeded

## Advanced Features

### Enhanced Text Processing
- **85-character line width** for optimal readability
- **18-line message capacity** with automatic wrapping
- **Smart word wrapping** preserves word boundaries
- **Overflow handling** with "...more" indicator

### Page Numbering
- **With coversheet**: Pages numbered 1, 2, 3... (coversheet is page 1)
- **Without coversheet**: Pages numbered 1, 2, 3... (PDF pages only)
- **Automatic adjustment** based on coversheet presence

### Header Generation
Each page includes comprehensive headers:
- Sender information (name and phone)
- Recipient information (name and phone)
- Transmission date/time
- Page numbering (current/total)

## Troubleshooting

### Common Issues


#### "res_fax.so module not loaded"
```bash
# Load the fax module in Asterisk
asterisk -rx "module load res_fax.so"

# Add to modules.conf for permanent loading
echo "load => res_fax.so" >> /etc/asterisk/modules.conf
```


### Log Analysis
```bash
# Check recent fax attempts
grep "SendFax" /var/log/asterisk/full | tail -20

# Monitor call file processing
grep "call.*\.call" /var/log/asterisk/full | tail -10

# Check for errors
grep -i "error\|fail" /var/log/asterisk/full | grep -i fax | tail -10
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

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


