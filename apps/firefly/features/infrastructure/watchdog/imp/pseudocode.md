# Watchdog Pseudocode
*Platform-agnostic implementation logic for server health monitoring*

## Configuration

```
SERVER_URL = "http://localhost:8080/api/ping"
CHECK_INTERVAL = 60 seconds (via cron)
RESTART_DELAY = 3 seconds
LOG_RETENTION = indefinite (in bad/ folders)

EMAIL_FROM = "microclub <admin@microclub.org>"
EMAIL_TO = "ash.nehru@gmail.com"
SMTP_SERVER = "smtp.office365.com"
SMTP_PORT = 587
SMTP_USER = "admin@microclub.org"
SMTP_PASS = "Conf1dant!"
```

## Main Loop

```
function watchdog_check():
    log("Watchdog check started")

    # CRITICAL: Check PostgreSQL FIRST
    if not check_postgres():
        log("CRITICAL: PostgreSQL is down!")

        # Preserve evidence
        bad_dir = save_bad_logs()
        log("Logs saved to: " + bad_dir)

        # Restart PostgreSQL
        restart_postgres()
        wait(3 seconds)

        # Verify PostgreSQL recovered
        if not check_postgres():
            log("CRITICAL: PostgreSQL failed to restart!")
            send_email("PostgreSQL Failure - Cannot Restart", bad_dir)
            log("Email notification sent")
            return  # Cannot proceed without PostgreSQL

        log("PostgreSQL restarted successfully")

        # PostgreSQL was down, server likely needs restart too
        restart_server()
        wait(3 seconds)

        # Verify server recovery
        if check_server():
            log("SUCCESS: Server recovered after PostgreSQL restart")
            send_email("PostgreSQL + Server Recovered", bad_dir)
        else:
            log("ERROR: Server still down after PostgreSQL restart")
            send_email("Server Failed to Recover After PostgreSQL Restart", bad_dir)

        log("Email notification sent")
        log("Watchdog check completed")
        return

    # PostgreSQL is running, now check server
    if not check_server():
        log("ERROR: Server not responding (PostgreSQL is OK)")

        # Check for intentional shutdown
        intentional = check_intentional_shutdown_marker()
        if intentional:
            log("Detected intentional shutdown marker")
            remove_marker_file()
            log("Removed shutdown marker file")

        # Preserve evidence
        bad_dir = save_bad_logs()
        log("Logs saved to: " + bad_dir)

        # Restart server (PostgreSQL already confirmed running)
        restart_server()
        wait(3 seconds)

        # Verify recovery
        if check_server():
            log("SUCCESS: Server recovered")
            recovery_status = "RECOVERED"
        else:
            log("ERROR: Server still down after restart")
            recovery_status = "FAILED TO RECOVER"

        # Send email only if NOT intentional shutdown
        if not intentional:
            send_email("Server Failure - " + recovery_status, bad_dir)
            log("Email notification sent")
        else:
            log("Skipped email notification (intentional shutdown)")
    else:
        log("Server is healthy")

    log("Watchdog check completed")
```

## Health Check Functions

```
function check_server() -> boolean:
    response = http_get(SERVER_URL, timeout=5)
    return response.contains('"status":"ok"')

function check_postgres() -> boolean:
    processes = get_running_processes()
    return processes.contains("postgres.*postgresql@16")

function check_intentional_shutdown_marker() -> boolean:
    marker_file = "~/firefly-server/.intentional_shutdown"
    return file_exists(marker_file)

function remove_marker_file():
    marker_file = "~/firefly-server/.intentional_shutdown"
    delete_file(marker_file)
```

## Log Preservation

```
function save_bad_logs() -> string:
    timestamp = current_datetime("%Y%m%d_%H%M%S")
    bad_dir = "~/firefly-server/bad/" + timestamp

    create_directory(bad_dir)

    # Copy logs
    copy_file("server.log", bad_dir + "/")
    copy_file("watchdog.log", bad_dir + "/")

    # Save system state
    system_info = bad_dir + "/system_info.txt"
    write_file(system_info, "=== System Info ===")
    append_file(system_info, "Timestamp: " + current_datetime())
    append_file(system_info, "\n=== Processes ===")
    append_command_output(system_info, "ps aux | grep -E '(python|postgres)'")
    append_file(system_info, "\n=== Port 8080 ===")
    append_command_output(system_info, "lsof -i :8080")
    append_file(system_info, "\n=== Disk Space ===")
    append_command_output(system_info, "df -h")

    return bad_dir
```

## Service Restart

```
function restart_postgres():
    log("Restarting PostgreSQL...")
    execute("/opt/homebrew/opt/postgresql@16/bin/pg_ctl " +
            "-D /opt/homebrew/var/postgresql@16 " +
            "-l /opt/homebrew/var/log/postgresql@16.log start")

function restart_server():
    log("Restarting Firefly server...")
    execute("./stop.sh")
    wait(2 seconds)
    execute("./start.sh")
```

## Email Notification

```
function send_email(recovery_status, bad_dir):
    subject = "[Firefly] Server Failure Detected - " + recovery_status

    body = """
    The Firefly server on the Mac mini experienced a failure at {current_time}.

    Status: {recovery_status}

    Logs saved to: {bad_dir}

    Server URL: http://185.96.221.52:8080

    Actions taken:
    1. Saved logs to bad folder
    2. Checked PostgreSQL status
    3. Restarted server

    Please check the logs for details.

    - Firefly Watchdog
    """

    send_smtp_email(
        from=EMAIL_FROM,
        to=EMAIL_TO,
        subject=subject,
        body=body,
        smtp_server=SMTP_SERVER,
        smtp_port=SMTP_PORT,
        username=SMTP_USER,
        password=SMTP_PASS
    )
```

## Logging

```
function log(message):
    timestamp = current_datetime("%Y-%m-%d %H:%M:%S")
    append_file("watchdog.log", timestamp + " - " + message)
```

## Patching Instructions

### For Server (Shell Script)

**File**: `apps/firefly/product/server/imp/py/watchdog.sh`

1. Create the watchdog script with all configuration variables at the top
2. Implement health check functions using curl and process checks
3. Implement log preservation creating timestamped bad/ folders
4. Implement service restart using stop.sh/start.sh and pg_ctl
5. Implement email sending using Python embedded in shell script
6. Set up logging to watchdog.log with timestamps
7. Make executable: `chmod +x watchdog.sh`

### For Cron Schedule

**Command**: `crontab -e`

Add line:
```
* * * * * ~/firefly-server/watchdog.sh
```

This runs every minute. The `*` pattern means:
- Minute: every minute (0-59)
- Hour: every hour (0-23)
- Day of month: every day (1-31)
- Month: every month (1-12)
- Day of week: every day (0-6, Sunday=0)

### For DNS Configuration

**Command**: `networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4`

Required for email sending to work. Without DNS, SMTP server hostname cannot be resolved.

Verify with: `networksetup -getdnsservers Wi-Fi`

## Critical Details

1. **PostgreSQL-first checking**: MUST check PostgreSQL before server to prevent cascade failures. If PostgreSQL is down, the server will crash when trying to initialize its database connection pool, creating a restart loop.
2. **Connection timeout**: HTTP health check must timeout after 5 seconds to avoid hanging
3. **Restart delays**: Wait 2-3 seconds after service restarts before verification
4. **Log preservation**: Always save logs BEFORE restarting to capture failure state
5. **Email reliability**: Requires working DNS - Google's 8.8.8.8 is most reliable
6. **Process detection**: Use `grep -v grep` to avoid matching the grep command itself
7. **File permissions**: Watchdog script must be executable (`chmod +x`)
8. **Cron environment**: Cron runs with minimal PATH - use absolute paths for commands
9. **SMTP authentication**: Office365 requires EHLO, STARTTLS, EHLO sequence
10. **Intentional shutdown marker**: Server creates `.intentional_shutdown` file when shut down via API to suppress false-positive email alerts

## Error Handling

The watchdog should never crash. All operations are wrapped in try/catch equivalent:
- HTTP failures trigger recovery (that's the point)
- Email send failures are logged but don't block recovery
- Log file write failures are tolerated (worst case: no log entry)
- Directory creation failures are handled gracefully

## Testing

Simulate failure:
```bash
# Stop server
./stop.sh

# Wait for watchdog (max 60 seconds)
# Check it detected and recovered
tail -f watchdog.log

# Verify logs were saved
ls -la ~/firefly-server/bad/
```

Expected behavior:
- Within 60 seconds, watchdog detects failure
- Logs saved to bad/YYYYMMDD_HHMMSS/
- Server automatically restarts
- Email notification sent
- All actions logged in watchdog.log
