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

# Check if EMAIL_PASSWORD is set
if [ -z "$EMAIL_PASSWORD" ]; then
    echo "ERROR: EMAIL_PASSWORD not set in .env file" >> "$LOG_FILE"
    exit 1
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

# CRITICAL: Check PostgreSQL FIRST before checking server
if ! check_postgres; then
    log "CRITICAL: PostgreSQL is down!"

    # Save logs before restarting
    bad_dir=$(save_bad_logs)
    log "Logs saved to: $bad_dir"

    # Restart PostgreSQL
    restart_postgres
    sleep 3

    # Verify PostgreSQL is now running
    if ! check_postgres; then
        log "CRITICAL: PostgreSQL failed to restart!"
        subject="[Firefly] PostgreSQL Failure - Cannot Restart"
        body="PostgreSQL failed to restart on the Mac mini at $(date).

Logs saved to: $bad_dir

This requires manual intervention.

- Firefly Watchdog"
        send_email "$subject" "$body"
        log "Email notification sent to $NOTIFY_EMAIL"
        log "Watchdog check completed"
        exit 1
    fi

    log "PostgreSQL restarted successfully"

    # PostgreSQL was down, server likely needs restart too
    restart_server
    sleep 3

    # Verify recovery
    if check_server; then
        log "SUCCESS: Server recovered after PostgreSQL restart"
        subject="[Firefly] PostgreSQL + Server Recovered"
        body="PostgreSQL was down and has been restarted at $(date).

Server was also restarted and is now healthy.

Logs saved to: $bad_dir
Server URL: http://185.96.221.52:8080

- Firefly Watchdog"
        send_email "$subject" "$body"
        log "Email notification sent to $NOTIFY_EMAIL"
    else
        log "ERROR: Server still down after PostgreSQL restart"
        subject="[Firefly] Server Failed to Recover After PostgreSQL Restart"
        body="PostgreSQL was restarted but server is still down at $(date).

Logs saved to: $bad_dir

This requires manual intervention.

- Firefly Watchdog"
        send_email "$subject" "$body"
        log "Email notification sent to $NOTIFY_EMAIL"
    fi

    log "Watchdog check completed"
    exit 0
fi

# PostgreSQL is running, now check server health
if ! check_server; then
    log "ERROR: Server not responding (PostgreSQL is OK)"

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

    # Restart server (PostgreSQL already confirmed running)
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
