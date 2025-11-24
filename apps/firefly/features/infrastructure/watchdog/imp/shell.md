# Watchdog Shell Script Implementation
*Bash implementation for server health monitoring on macOS*

## File Location

`apps/firefly/product/server/imp/py/watchdog.sh`

## Complete Implementation

```bash
#!/bin/bash
# Firefly Server Watchdog
# Monitors server health and automatically recovers from failures

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

LOG_FILE="$SCRIPT_DIR/watchdog.log"
SERVER_URL="http://localhost:8080/api/ping"
NOTIFY_EMAIL="ash.nehru@gmail.com"

# Load EMAIL_PASSWORD from .env file
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | grep EMAIL_PASSWORD | xargs)
fi

SMTP_HOST="smtp.office365.com"
SMTP_PORT="587"
SMTP_USER="admin@microclub.org"
SMTP_PASS="$EMAIL_PASSWORD"
SMTP_FROM="microclub <admin@microclub.org>"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Send email notification
send_email() {
    local subject="$1"
    local body="$2"

    # Use Python to send email (reusing server's SMTP credentials)
    python3 << EOF
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

try:
    msg = MIMEMultipart()
    msg['From'] = "$SMTP_FROM"
    msg['To'] = "$NOTIFY_EMAIL"
    msg['Subject'] = "$subject"
    msg.attach(MIMEText("""$body""", 'plain'))

    with smtplib.SMTP('$SMTP_HOST', $SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login('$SMTP_USER', '$SMTP_PASS')
        server.sendmail('$SMTP_USER', '$NOTIFY_EMAIL', msg.as_string())

    print("Email sent successfully")
except Exception as e:
    print(f"Failed to send email: {e}")
EOF
}

# Check if server is responding
check_server() {
    if curl -s --max-time 5 "$SERVER_URL" | grep -q '"status":"ok"'; then
        return 0  # Server is healthy
    else
        return 1  # Server is down
    fi
}

# Check if PostgreSQL is running
check_postgres() {
    if ps aux | grep -v grep | grep -q "postgres.*postgresql@16"; then
        return 0  # PostgreSQL is running
    else
        return 1  # PostgreSQL is down
    fi
}

# Save logs to bad folder
save_bad_logs() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local bad_dir="$SCRIPT_DIR/bad/$timestamp"

    mkdir -p "$bad_dir"

    # Copy server log
    if [ -f "$SCRIPT_DIR/server.log" ]; then
        cp "$SCRIPT_DIR/server.log" "$bad_dir/"
    fi

    # Copy watchdog log
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "$bad_dir/"
    fi

    # Save system info
    echo "=== System Info ===" > "$bad_dir/system_info.txt"
    echo "Timestamp: $(date)" >> "$bad_dir/system_info.txt"
    echo "" >> "$bad_dir/system_info.txt"
    echo "=== Processes ===" >> "$bad_dir/system_info.txt"
    ps aux | grep -E "(python|postgres)" | grep -v grep >> "$bad_dir/system_info.txt"
    echo "" >> "$bad_dir/system_info.txt"
    echo "=== Port 8080 ===" >> "$bad_dir/system_info.txt"
    lsof -i :8080 >> "$bad_dir/system_info.txt" 2>&1
    echo "" >> "$bad_dir/system_info.txt"
    echo "=== Disk Space ===" >> "$bad_dir/system_info.txt"
    df -h >> "$bad_dir/system_info.txt"

    echo "$bad_dir"
}

# Restart PostgreSQL
restart_postgres() {
    log "Restarting PostgreSQL..."
    /opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start
}

# Restart server
restart_server() {
    log "Restarting Firefly server..."
    cd "$SCRIPT_DIR"
    ./stop.sh >> "$LOG_FILE" 2>&1
    sleep 2
    ./start.sh >> "$LOG_FILE" 2>&1
}

# Main watchdog logic
log "Watchdog check started"

# Check server health
if ! check_server; then
    log "ERROR: Server not responding!"

    # Check if this was an intentional shutdown
    MARKER_FILE="$SCRIPT_DIR/.intentional_shutdown"
    intentional_shutdown=false
    if [ -f "$MARKER_FILE" ]; then
        log "Detected intentional shutdown marker file"
        intentional_shutdown=true
        rm -f "$MARKER_FILE"
        log "Removed shutdown marker file"
    fi

    # Save logs before restarting
    bad_dir=$(save_bad_logs)
    log "Logs saved to: $bad_dir"

    # Check PostgreSQL
    if ! check_postgres; then
        log "ERROR: PostgreSQL is down!"
        restart_postgres
        sleep 3
    fi

    # Restart server
    restart_server
    sleep 3

    # Verify recovery
    if check_server; then
        log "SUCCESS: Server recovered"
        recovery_status="RECOVERED"
    else
        log "ERROR: Server still down after restart"
        recovery_status="FAILED TO RECOVER"
    fi

    # Send email notification only if this was NOT an intentional shutdown
    if [ "$intentional_shutdown" = false ]; then
        subject="[Firefly] Server Failure Detected - $recovery_status"
    body="The Firefly server on the Mac mini experienced a failure at $(date).

Status: $recovery_status

Logs saved to: $bad_dir

Server URL: http://185.96.221.52:8080

Actions taken:
1. Saved logs to bad folder
2. Checked PostgreSQL status
3. Restarted server

Please check the logs for details.

- Firefly Watchdog"

        send_email "$subject" "$body"
        log "Email notification sent to $NOTIFY_EMAIL"
    else
        log "Skipped email notification (intentional shutdown via API)"
    fi

else
    log "Server is healthy"
fi

log "Watchdog check completed"
```

## Installation

1. **Create the script**:
   ```bash
   cd ~/firefly-server
   # Create watchdog.sh with above content
   chmod +x watchdog.sh
   ```

2. **Add to crontab**:
   ```bash
   crontab -e
   # Add line:
   * * * * * ~/firefly-server/watchdog.sh
   ```

3. **Configure DNS** (required for email):
   ```bash
   sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4
   ```

4. **Verify DNS**:
   ```bash
   networksetup -getdnsservers Wi-Fi
   # Should show: 8.8.8.8, 8.8.4.4
   ```

## Testing

Simulate a server failure:

```bash
# Stop the server
cd ~/firefly-server
./stop.sh

# Watch the watchdog log (in another terminal)
tail -f ~/firefly-server/watchdog.log

# Within 60 seconds, you should see:
# - "ERROR: Server not responding!"
# - "Logs saved to: ~/firefly-server/bad/YYYYMMDD_HHMMSS"
# - "Restarting Firefly server..."
# - "SUCCESS: Server recovered"
# - "Email notification sent to ash.nehru@gmail.com"

# Check the saved logs
ls -la ~/firefly-server/bad/
```

## Key Implementation Details

### Email Sending via Embedded Python

The script embeds Python code using a heredoc to send emails:
- Bash variables are expanded in the heredoc (e.g., `$SMTP_HOST`)
- Python handles the SMTP protocol complexity
- Errors are caught and printed but don't crash the watchdog

### Health Check Logic

```bash
check_server() {
    if curl -s --max-time 5 "$SERVER_URL" | grep -q '"status":"ok"'; then
        return 0  # Server is healthy
    else
        return 1  # Server is down
    fi
}
```

- `-s`: Silent mode (no progress bars)
- `--max-time 5`: 5-second timeout prevents hanging
- `grep -q`: Quiet mode returns exit code 0 if found
- Return codes: 0=success, 1=failure (Bash convention)

### PostgreSQL Detection

```bash
check_postgres() {
    if ps aux | grep -v grep | grep -q "postgres.*postgresql@16"; then
        return 0
    else
        return 1
    fi
}
```

- `ps aux`: List all processes
- `grep -v grep`: Exclude the grep command itself
- Pattern matches PostgreSQL 16 specifically

### Log Preservation

Creates timestamped directories:
```bash
timestamp=$(date '+%Y%m%d_%H%M%S')  # e.g., 20251116_110511
bad_dir="$SCRIPT_DIR/bad/$timestamp"
mkdir -p "$bad_dir"
```

Saves three types of information:
1. **server.log**: Flask app output leading to crash
2. **watchdog.log**: Watchdog's detection and recovery actions
3. **system_info.txt**: Process list, port usage, disk space

### Recovery Timing

```bash
restart_server
sleep 3
if check_server; then
    # Server recovered
```

The 3-second sleep allows:
- Flask app to initialize
- Database connections to establish
- Server to bind to port 8080
- Health check endpoint to become available

Too short: False failure detection
Too long: Unnecessary delay in verification

### Cron Environment

Cron runs with minimal environment:
- No `$PATH` from user shell
- No aliases or functions
- Working directory may differ

Solutions:
- Use absolute paths: `/opt/homebrew/opt/postgresql@16/bin/pg_ctl`
- Set working directory: `cd "$SCRIPT_DIR"`
- Use `$SCRIPT_DIR` for relative file paths

### DNS Requirement

Without DNS configured, email sending fails with:
```
Failed to send email: [Errno 8] nodename nor servname provided, or not known
```

This happens because `smtp.office365.com` cannot be resolved to an IP address.

**Fix**: Configure Google's public DNS servers on the WiFi interface:
```bash
sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4
```

**Why it happens**: macOS sometimes loses DNS configuration after:
- System reboots
- macOS updates
- Network interface resets
- WiFi reconnections

**Verification**: Test DNS resolution works:
```bash
nslookup smtp.office365.com
# Should return IP addresses
```

## Error Scenarios

### Scenario 1: Server Down, PostgreSQL Running
```
Watchdog check started
ERROR: Server not responding!
Logs saved to: ~/firefly-server/bad/20251116_110511
Restarting Firefly server...
SUCCESS: Server recovered
Email notification sent to ash.nehru@gmail.com
Watchdog check completed
```

### Scenario 2: Both Server and PostgreSQL Down
```
Watchdog check started
ERROR: Server not responding!
Logs saved to: ~/firefly-server/bad/20251116_110623
ERROR: PostgreSQL is down!
Restarting PostgreSQL...
Restarting Firefly server...
SUCCESS: Server recovered
Email notification sent to ash.nehru@gmail.com
Watchdog check completed
```

### Scenario 3: Failed Recovery
```
Watchdog check started
ERROR: Server not responding!
Logs saved to: ~/firefly-server/bad/20251116_110745
Restarting Firefly server...
ERROR: Server still down after restart
Email notification sent to ash.nehru@gmail.com
Watchdog check completed
```

Email will indicate "FAILED TO RECOVER" for manual investigation.

## Maintenance

### View Recent Watchdog Activity
```bash
tail -50 ~/firefly-server/watchdog.log
```

### View Saved Failure Logs
```bash
ls -la ~/firefly-server/bad/
cd ~/firefly-server/bad/20251116_110511
cat system_info.txt
tail server.log
```

### Disable Watchdog Temporarily
```bash
crontab -e
# Comment out the watchdog line:
# * * * * * ~/firefly-server/watchdog.sh
```

### Clear Old Failure Logs
```bash
# Keep only last 30 days
find ~/firefly-server/bad -type d -mtime +30 -exec rm -rf {} \;
```

## Security Considerations

**Credentials in Script**: The SMTP password is stored in plain text in the watchdog script. This is acceptable for:
- Local monitoring scripts on trusted servers
- Service accounts (admin@microclub.org) with limited scope
- Non-critical email notifications

**Not acceptable for**: Production secrets, API keys for critical services

**Better alternative for production**: Use environment variables or macOS Keychain

**File Permissions**: Ensure watchdog.sh is only readable by the server user:
```bash
chmod 700 ~/firefly-server/watchdog.sh
```
