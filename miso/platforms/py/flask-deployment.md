# Flask Deployment
*Running Flask applications on macOS*

Generic knowledge for deploying and running Flask web applications.

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

### 2. Install Flask

```bash
pip3 install flask
```

Or with requirements file:
```bash
pip3 install -r requirements.txt
```

### 3. Verify Installation

```bash
python3 -c "import flask; print(flask.__version__)"
```

## Running Flask Apps

### Development Mode (Interactive)

Start server from terminal:
```bash
python3 app.py
```

Flask development server features:
- Auto-reload on code changes
- Detailed error messages
- Interactive debugger
- Single-threaded
- Stops when terminal closes

**Important**: Use `host='0.0.0.0'` to accept external connections, not just localhost.

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

Or:
```bash
lsof -ti:8080 | xargs kill
```

### Using launchd (macOS Service)

For automatic startup on boot, create a launchd service.

**File**: `~/Library/LaunchAgents/com.yourapp.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourapp.server</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/python3</string>
        <string>/path/to/your/app.py</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/path/to/your/app</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/username/app-server.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/username/app-server-error.log</string>
</dict>
</plist>
```

**Load service**:
```bash
launchctl load ~/Library/LaunchAgents/com.yourapp.plist
```

**Unload service**:
```bash
launchctl unload ~/Library/LaunchAgents/com.yourapp.plist
```

**Check status**:
```bash
launchctl list | grep yourapp
```

## Firewall Configuration

### macOS Firewall

Allow incoming connections:

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

## Troubleshooting

### Port already in use

```
OSError: [Errno 48] Address already in use
```

**Fix**: Kill existing process on that port
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
