# Server Deployment
*Setting up and running the Firefly server*

Documentation for deploying the Flask server on a Mac mini for development and testing.

## Server Environment

- **Hardware**: Mac mini
- **Local IP**: 192.168.1.76
- **Public IP**: 185.96.221.52
- **Operating System**: macOS
- **Python**: 3.x required

## Initial Setup

### 1. Install Python

Check if Python is installed:
```bash
python3 --version
```

If not installed, download from [python.org](https://www.python.org/) or use Homebrew:
```bash
brew install python3
```

### 2. Install Dependencies

Navigate to server directory:
```bash
cd /path/to/apps/firefly/server/imp/py
```

Install Flask:
```bash
pip3 install -r requirements.txt
```

Or install directly:
```bash
pip3 install flask
```

### 3. Verify Installation

```bash
python3 -c "import flask; print(flask.__version__)"
```

Should output Flask version (e.g., `3.0.0`)

## Running the Server

### Development Mode (Interactive)

Start server from terminal:
```bash
cd /path/to/apps/firefly/server/imp/py
python3 app.py
```

Output:
```
 * Serving Flask app 'app'
 * Debug mode: on
WARNING: This is a development server. Do not use it in a production deployment.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8080
 * Running on http://192.168.1.76:8080
Press CTRL+C to quit
 * Restarting with stat
 * Debugger is active!
```

**Features**:
- Auto-reload on code changes
- Detailed error messages
- Interactive debugger

**Limitations**:
- Single-threaded
- Stops when terminal closes
- Not suitable for production

### Background Mode (nohup)

Run server in background that persists after closing terminal:

```bash
nohup python3 app.py > server.log 2>&1 &
```

**Explanation**:
- `nohup`: Ignore hangup signal (keep running when terminal closes)
- `> server.log`: Redirect stdout to log file
- `2>&1`: Redirect stderr to same file
- `&`: Run in background

Check if running:
```bash
ps aux | grep app.py
```

View logs:
```bash
tail -f server.log
```

Stop server:
```bash
# Find process ID
ps aux | grep app.py

# Kill process
kill <PID>
```

### Using launchd (macOS Service)

For automatic startup on boot, create a launchd service.

**File**: `~/Library/LaunchAgents/com.miso.firefly.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.miso.firefly</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/python3</string>
        <string>/path/to/apps/firefly/server/imp/py/app.py</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>/path/to/apps/firefly/server/imp/py</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/Users/username/firefly-server.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/username/firefly-server-error.log</string>
</dict>
</plist>
```

**Load service**:
```bash
launchctl load ~/Library/LaunchAgents/com.miso.firefly.plist
```

**Unload service**:
```bash
launchctl unload ~/Library/LaunchAgents/com.miso.firefly.plist
```

**Check status**:
```bash
launchctl list | grep firefly
```

## Testing Deployment

### Test Locally

```bash
curl http://localhost:8080/api/ping
```

### Test from Local Network

From another device on same network:
```bash
curl http://192.168.1.76:8080/api/ping
```

### Test from Internet

From external network or mobile data:
```bash
curl http://185.96.221.52:8080/api/ping
```

Expected response:
```json
{
  "message": "Firefly server is alive!",
  "status": "ok"
}
```

## Firewall Configuration

### macOS Firewall

Allow incoming connections on port 8080:

1. System Settings → Network → Firewall
2. Firewall Options
3. Add Python (or specific app)
4. Allow incoming connections

Or use command line:
```bash
# Allow Python through firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/python3
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/local/bin/python3
```

## Network Configuration

For the server to be accessible from the internet, router must forward port 8080:
- See `server/network.md` for port forwarding setup

## Monitoring

### Check if server is running

```bash
# Check process
ps aux | grep app.py

# Check port
lsof -i :8080

# Test connection
curl http://localhost:8080/api/ping
```

### View logs (if using nohup)

```bash
tail -f server.log
```

### View logs (if using launchd)

```bash
tail -f ~/firefly-server.log
tail -f ~/firefly-server-error.log
```

## Troubleshooting

### Port already in use

```
OSError: [Errno 48] Address already in use
```

**Fix**: Kill existing process on port 8080
```bash
lsof -ti:8080 | xargs kill
```

### Permission denied

```
PermissionError: [Errno 13] Permission denied
```

**Fix**: Don't use port < 1024 (requires root), or use sudo (not recommended)

### Module not found

```
ModuleNotFoundError: No module named 'flask'
```

**Fix**: Install Flask in correct Python environment
```bash
pip3 install flask
```

### Connection refused from internet

**Possible causes**:
- Router not forwarding port 8080
- macOS firewall blocking connections
- ISP blocking incoming traffic
- Server not running on 0.0.0.0

## Production Considerations

For production use (beyond development/testing):

1. **Use Production WSGI Server**:
   ```bash
   pip3 install gunicorn
   gunicorn -w 4 -b 0.0.0.0:8080 app:app
   ```

2. **Add HTTPS**: Use nginx reverse proxy with Let's Encrypt certificate

3. **Environment Variables**: Externalize configuration

4. **Logging**: Proper log rotation and management

5. **Monitoring**: Use monitoring service (e.g., Datadog, New Relic)

6. **Auto-restart**: Use process manager (e.g., supervisor, systemd)

7. **Security**: Firewall rules, rate limiting, authentication

## Current Status

The Firefly server is currently running in development mode:
- Accessible at http://185.96.221.52:8080
- Running Flask development server
- Debug mode enabled
- Port forwarding configured on router

This is suitable for development and testing but should be upgraded for production use.
