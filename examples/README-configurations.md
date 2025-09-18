# Example Configurations

This directory contains example configuration files for different Asterisk setups and use cases.

## Configuration Files

### sendfax.conf - Main Configuration Template
Basic configuration template with common settings:
```bash
# --- Asterisk SendFax Configuration Template ---

# Channel Technology (PJSIP recommended, SIP for legacy)
TECH="PJSIP"

# SIP Trunk Configuration
TRUNK_NAME="your-fax-provider"          # Name from pjsip.conf or sip.conf
CALLERID="Your Company <+15551234567>"  # Your caller ID

# Fax Options
EXTRA_FAX_OPTS="df"    # d=ECM enabled, f=use V.17 fallback
FAX_PRIORITY="Normal"  # Default priority: Normal, Urgent, High, Low

# System Paths
SPOOL_DIR="/var/spool/asterisk/outgoing"  # Asterisk outgoing spool
```

### PJSIP Examples

#### pjsip-cloud-provider.conf - Cloud Fax Provider
```ini
; Example for cloud fax services (e.g., Twilio, Bandwidth)
[fax-provider-endpoint]
type=endpoint
context=outbound-fax
disallow=all
allow=alaw
allow=ulaw
outbound_auth=fax-provider-auth
aors=fax-provider-aor
direct_media=no

[fax-provider-aor]
type=aor
contact=sip:sip.your-provider.com

[fax-provider-auth]
type=auth
auth_type=userpass
username=your-account-sid
password=your-auth-token

; SendFax script configuration
TECH="PJSIP"
TRUNK_NAME="fax-provider-endpoint"
CALLERID="Your Business <+15551234567>"
```

#### pjsip-traditional-pstn.conf - Traditional PSTN Gateway
```ini
; Example for traditional PSTN gateway
[pstn-gateway]
type=endpoint
context=outbound-fax
disallow=all
allow=alaw
allow=ulaw
outbound_auth=pstn-auth
aors=pstn-aor
send_rpid=yes
trust_id_inbound=yes

[pstn-aor]
type=aor
contact=sip:192.168.1.100:5060

[pstn-auth]
type=auth
auth_type=userpass
username=asterisk
password=secure-password

; SendFax script configuration
TECH="PJSIP"
TRUNK_NAME="pstn-gateway"
CALLERID="Office Main <+15551234567>"
```

### Legacy SIP Examples

#### sip-legacy.conf - Legacy SIP Channel
```ini
; sip.conf example for older Asterisk versions
[fax-trunk]
type=friend
host=sip.faxprovider.com
username=your-username
secret=your-password
disallow=all
allow=alaw
allow=ulaw
context=outbound-fax
qualify=yes

; SendFax script configuration
TECH="SIP"
TRUNK_NAME="fax-trunk"
CALLERID="Your Name <+15551234567>"
```

### extensions.conf Examples

#### Basic Outbound Context
```ini
[outbound-fax]
; Simple outbound fax context
exten => _X.,1,NoOp(Outbound Fax to ${EXTEN})
exten => _X.,n,Set(FAXOPT(gateway)=yes)
exten => _X.,n,Dial(PJSIP/${EXTEN}@fax-provider-endpoint,60)
exten => _X.,n,Hangup()
```

#### Advanced Fax Context with Logging
```ini
[outbound-fax]
; Advanced fax context with comprehensive logging
exten => _X.,1,NoOp(=== Outbound Fax Session Start ===)
exten => _X.,n,Set(FAXOPT(gateway)=yes)
exten => _X.,n,Set(FAXOPT(debug)=yes)
exten => _X.,n,Set(CDR(accountcode)=FAX-OUT)
exten => _X.,n,Dial(PJSIP/${EXTEN}@fax-provider-endpoint,120)
exten => _X.,n,NoOp(Dial Result: ${DIALSTATUS})
exten => _X.,n,GotoIf($["${DIALSTATUS}" = "ANSWER"]?success:failed)

exten => _X.,n(success),NoOp(=== Fax Transmission Successful ===)
exten => _X.,n,Hangup()

exten => _X.,n(failed),NoOp(=== Fax Transmission Failed: ${DIALSTATUS} ===)
exten => _X.,n,Hangup()
```

### Provider-Specific Examples

#### Twilio Configuration
```bash
# Twilio-specific settings
TECH="PJSIP"
TRUNK_NAME="twilio-fax"
CALLERID="Your Business <+15551234567>"
EXTRA_FAX_OPTS="df"

# Note: Twilio requires specific codec and timing settings
# See pjsip.conf example above
```

#### RingCentral Configuration
```bash
# RingCentral fax settings
TECH="PJSIP" 
TRUNK_NAME="ringcentral-fax"
CALLERID="Company Name <+15551234567>"
EXTRA_FAX_OPTS="d"  # ECM enabled

# RingCentral typically requires G.711 codec only
```

#### FreePBX Integration
```bash
# FreePBX trunk integration
TECH="PJSIP"
TRUNK_NAME="pjsip-fax-trunk"  # Use FreePBX trunk name
CALLERID="Office <+15551234567>"
SPOOL_DIR="/var/spool/asterisk/outgoing"
```

### Testing Configurations

#### test-local.conf - Local Testing
```bash
# Local testing configuration
TECH="Local"
TRUNK_NAME="test-context"
CALLERID="Test User <+15551234567>"
FAX_PRIORITY="Normal"

# For testing without actual fax transmission
# Requires local context in extensions.conf
```

#### debug-verbose.conf - Debugging Setup
```bash
# Enhanced debugging configuration
TECH="PJSIP"
TRUNK_NAME="debug-trunk"
CALLERID="Debug Test <+15551234567>"
EXTRA_FAX_OPTS="df"

# Add these for debugging:
# - Enable Asterisk console: asterisk -rvvv
# - Monitor logs: tail -f /var/log/asterisk/full
# - Set debug level: core set debug 3
```

## Usage Examples by Scenario

### Small Office Setup
```bash
# Basic small office configuration
TECH="PJSIP"
TRUNK_NAME="office-fax-line"
CALLERID="ABC Company <+15551234567>"
FAX_PRIORITY="Normal"

# Typical usage:
./sendfax.sh 5551234567 contract.pdf "Contract Review" "Please review attached."
```

### Enterprise Environment  
```bash
# Enterprise with multiple trunks
TECH="PJSIP"
TRUNK_NAME="enterprise-fax-trunk"
CALLERID="Enterprise Corp <+15551234567>"
FAX_PRIORITY="High"
SPOOL_DIR="/var/spool/asterisk/outgoing"

# High-volume usage with priority routing
./sendfax.sh --cover "Client Name <+15551234567>" urgent.pdf "URGENT" "Immediate attention required" "Urgent"
```

### International Setup
```bash
# International fax configuration
TECH="PJSIP"
TRUNK_NAME="international-gateway"  
CALLERID="Global Business <+15551234567>"
EXTRA_FAX_OPTS="d"  # ECM for reliability

# International number format
./sendfax.sh "Hans Mueller <+49301234567>" document.pdf "Quarterly Report" "Q4 results attached"
```

## Troubleshooting by Configuration

### Common Issues and Solutions

#### PJSIP Registration Problems
```bash
# Check registration status
asterisk -rx "pjsip show registrations"

# Test endpoint reachability
asterisk -rx "pjsip show endpoints"
```

#### Codec Negotiation Issues
```ini
; Force specific codecs in pjsip.conf
[your-endpoint]
disallow=all
allow=ulaw
allow=alaw
; Remove other codecs that might cause issues
```

#### Timeout Issues
```ini
; Increase timeouts for fax transmissions
[your-endpoint]
timers_sess_expires=1800
timers_min_se=120
```

For more specific configuration help, please refer to the main README.md or submit an issue with your particular setup details.