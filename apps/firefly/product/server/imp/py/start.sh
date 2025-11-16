#!/bin/bash
# Start the Firefly server

# Kill any existing server on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null

# Add timestamp separator to log
echo "" >> server.log
echo "==================================================" >> server.log
echo "Server starting at $(date)" >> server.log
echo "==================================================" >> server.log

# Start the server in background (append to log instead of overwrite)
nohup python3 app.py >> server.log 2>&1 &
echo $! > server.pid

echo "Firefly server started on port 8080"
echo "PID: $(cat server.pid)"
echo "Logs: tail -f server.log"
echo "Stop: ./stop.sh"
echo "Access at: http://185.96.221.52:8080"
