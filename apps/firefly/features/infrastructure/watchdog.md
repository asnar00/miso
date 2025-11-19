# watchdog
*Automatic server health monitoring and recovery*

The watchdog monitors the Firefly server health every minute and automatically recovers from failures.

## Health Checks

The watchdog performs two checks:
- **Server responsiveness**: Checks if `/api/ping` endpoint responds with status "ok"
- **PostgreSQL status**: Verifies PostgreSQL is running

## Automatic Recovery

When a failure is detected, the watchdog:

1. **Preserves evidence**: Creates a timestamped folder in `~/firefly-server/bad/YYYYMMDD_HHMMSS/` containing:
   - Server log with all output leading to the crash
   - Watchdog log showing detection and recovery
   - System info (running processes, port usage, disk space)

2. **Restarts services**:
   - Starts PostgreSQL if it's down
   - Restarts the Flask server
   - Waits 3 seconds for stabilization

3. **Verifies recovery**:
   - Tests if server responds to `/api/ping`
   - Logs success or failure

4. **Sends notification**:
   - Emails administrator with failure details (only for unexpected failures)
   - Skips email if shutdown was intentional via `/api/shutdown` or `/api/restart` endpoints
   - Includes recovery status (RECOVERED or FAILED TO RECOVER)
   - Provides path to saved logs for investigation

## Intentional Shutdown Detection

The watchdog distinguishes between crashes and intentional shutdowns:
- When the server shuts down via `/api/shutdown` or `/api/restart`, it creates a marker file `.intentional_shutdown`
- The watchdog detects this marker and skips sending email notifications
- The marker is automatically removed after detection
- This prevents false alerts during deployments or manual restarts

## Email Notifications

Emails are sent to the administrator when **unexpected** failures occur. Each notification includes:
- Timestamp of failure
- Actions taken by watchdog
- Recovery status
- Path to saved logs
- Server URL for verification

**Email configuration**:
- Sender: microclub <admin@microclub.org>
- Recipient: ash.nehru@gmail.com
- SMTP: smtp.office365.com:587

## Logging

The watchdog maintains its own log at `~/firefly-server/watchdog.log`:
- Each check is logged with timestamp
- Health status recorded every run
- Detailed recovery actions when failures occur
- Email notification confirmations

## Schedule

Runs via cron every minute: `* * * * * ~/firefly-server/watchdog.sh`

This provides:
- Maximum 1-minute downtime before automatic recovery
- Continuous monitoring without manual intervention
- Historical log of all failures in `bad/` folders

## DNS Requirement

The watchdog requires working DNS to send email notifications. Google's public DNS servers (8.8.8.8, 8.8.4.4) are configured on the WiFi interface to ensure reliable domain resolution.
