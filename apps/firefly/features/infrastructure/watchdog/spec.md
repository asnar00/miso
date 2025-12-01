# watchdog
*Automatic server health monitoring and recovery*

The watchdog monitors the Firefly server health every minute and automatically recovers from failures.

## Health Checks

The watchdog performs two checks **in this critical order**:
1. **PostgreSQL status** (checked FIRST): Verifies PostgreSQL is running
2. **Server responsiveness**: Checks if `/api/ping` endpoint responds with status "ok"

**Why PostgreSQL first?** The server requires PostgreSQL to initialize its database connection pool during startup. Checking PostgreSQL first prevents cascade failures where a stopped database causes the server to crash during restart attempts.

## Automatic Recovery

When PostgreSQL is down:
1. **Saves crash logs** to `~/firefly-server/bad/YYYYMMDD_HHMMSS/`
2. **Restarts PostgreSQL** and waits 3 seconds
3. **Restarts the server** (since it likely failed without PostgreSQL)
4. **Verifies recovery** by checking server health
5. **Sends email** with recovery status and log location

When server is down (but PostgreSQL is running):
1. **Checks for intentional shutdown** (looks for `.intentional_shutdown` marker file)
2. **Saves crash logs** to `~/firefly-server/bad/YYYYMMDD_HHMMSS/`
3. **Restarts the server** and waits 3 seconds
4. **Verifies recovery** by checking `/api/ping`
5. **Sends email** (only if not intentional) with recovery status

**Evidence preservation**: Each crash creates a folder containing:
- Server log with all output leading to the crash
- Watchdog log showing detection and recovery
- System info (running processes, port usage, disk space)

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
