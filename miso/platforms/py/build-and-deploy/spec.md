# build-and-deploy
*complete workflow to deploy Python/Flask server to remote machine*

This document describes the complete process to deploy a Flask server to a remote machine (Mac mini in our case).

## Prerequisites

- SSH access to remote server (password-less preferred)
- Python 3.x installed on remote server
- Flask installed on remote server (`pip3 install flask`)
- Server project structure set up on remote machine

## Remote Server Details

For the Firefly server:
- **Host**: `microserver@192.168.1.76`
- **Remote directory**: `~/firefly-server/`
- **Server port**: `8080`
- **Server URL**: `http://192.168.1.76:8080`

## Steps

### 1. Stop Running Server

**Option A: Via API (preferred)**
```bash
curl -X POST http://192.168.1.76:8080/api/shutdown
```

**Option B: Via SSH**
```bash
ssh microserver@192.168.1.76 "cd ~/firefly-server && ./stop.sh"
```

**Option C: Find and kill process**
```bash
ssh microserver@192.168.1.76 "lsof -ti:8080 | xargs kill"
```

### 2. Copy Updated Files

```bash
scp /local/path/to/files/* microserver@192.168.1.76:~/firefly-server/
```

For specific files:
```bash
scp app.py requirements.txt *.sh microserver@192.168.1.76:~/firefly-server/
```

### 3. Install Dependencies (if requirements changed)

```bash
ssh microserver@192.168.1.76 "cd ~/firefly-server && pip3 install -r requirements.txt"
```

### 4. Start Server

```bash
ssh microserver@192.168.1.76 "cd ~/firefly-server && ./start.sh"
```

The `start.sh` script:
- Kills any existing server on port 8080
- Starts server in background with `nohup`
- Saves PID to `server.pid`
- Logs to `server.log`

### 5. Verify Server is Running

```bash
curl -s http://192.168.1.76:8080/api/ping
```

Expected response:
```json
{"message":"Firefly server is running","status":"ok"}
```

## Complete Example Script

For the Firefly server at `apps/firefly/product/server/imp/py/`:

```bash
#!/bin/bash

LOCAL_DIR="/Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/server/imp/py"
REMOTE_HOST="microserver@192.168.1.76"
REMOTE_DIR="~/firefly-server"
SERVER_URL="http://192.168.1.76:8080"

echo "🛑 Stopping remote server..."
curl -s -X POST "$SERVER_URL/api/shutdown" > /dev/null 2>&1
sleep 1

echo "📦 Copying files to Mac mini..."
scp "$LOCAL_DIR"/*.py "$LOCAL_DIR"/*.txt "$LOCAL_DIR"/*.sh "$REMOTE_HOST:$REMOTE_DIR/"

if [ $? -ne 0 ]; then
    echo "❌ File copy failed"
    exit 1
fi

echo "✅ Files copied"
echo "🚀 Starting server..."

ssh "$REMOTE_HOST" "cd $REMOTE_DIR && chmod +x *.sh && ./start.sh"

if [ $? -ne 0 ]; then
    echo "❌ Server start failed"
    exit 1
fi

echo "⏳ Waiting for server to start..."
sleep 2

echo "🔍 Verifying server..."
RESPONSE=$(curl -s "$SERVER_URL/api/ping")

if echo "$RESPONSE" | grep -q "ok"; then
    echo "✅ Deployment complete!"
    echo "📡 Server running at: $SERVER_URL"
else
    echo "❌ Server not responding correctly"
    exit 1
fi
```

## Troubleshooting

**"Connection refused" when accessing server**
- Check server is running: `ssh microserver@192.168.1.76 "ps aux | grep python"`
- Check logs: `ssh microserver@192.168.1.76 "cat ~/firefly-server/server.log"`
- Check firewall settings on Mac mini

**"Permission denied" during scp**
- Verify SSH key authentication is set up
- Check remote directory exists and has write permissions
- Try with verbose: `scp -v ...`

**Server starts but crashes immediately**
- Check logs: `ssh microserver@192.168.1.76 "tail ~/firefly-server/server.log"`
- Verify Python dependencies: `ssh microserver@192.168.1.76 "pip3 list | grep -i flask"`
- Check port 8080 isn't blocked or in use

**"Address already in use" error**
- Port 8080 still occupied from previous run
- Kill process: `ssh microserver@192.168.1.76 "lsof -ti:8080 | xargs kill -9"`
- Wait a few seconds and try again

## Server Management Commands

**View server logs:**
```bash
ssh microserver@192.168.1.76 "tail -f ~/firefly-server/server.log"
```

**Check server status:**
```bash
curl http://192.168.1.76:8080/api/ping
```

**Stop server:**
```bash
curl -X POST http://192.168.1.76:8080/api/shutdown
```

**Get server PID:**
```bash
ssh microserver@192.168.1.76 "cat ~/firefly-server/server.pid"
```

**Manual restart:**
```bash
ssh microserver@192.168.1.76 "cd ~/firefly-server && ./stop.sh && ./start.sh"
```

## Typical Deployment Time

- Stop server: <1 second (via API)
- Copy files: ~1-2 seconds (local network)
- Start server: ~1-2 seconds
- Verification: <1 second

Total deployment time: **~3-5 seconds**

## Security Notes

- Server runs without authentication (development only)
- Uses HTTP not HTTPS (local network only)
- `/api/shutdown` endpoint allows remote shutdown
- For production: add authentication, use HTTPS, remove shutdown endpoint

## Remote Directory Structure

```
~/firefly-server/
├── app.py              # Main Flask application
├── requirements.txt    # Python dependencies
├── start.sh           # Start server script
├── stop.sh            # Stop server script
├── remote-shutdown.sh # Remote shutdown script
├── server.log         # Server logs (created at runtime)
└── server.pid         # Process ID (created at runtime)
```

## Flask Server Configuration

The server runs with:
- **Host**: `0.0.0.0` (accessible from network)
- **Port**: `8080`
- **Debug mode**: `False` (for stability)
- **Process**: Background via `nohup`
