#!/bin/bash
# Start the Firefly server

# Kill any existing server on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null

# Start the server in background
nohup python3 app.py > server.log 2>&1 &
echo $! > server.pid

echo "Firefly server started on port 8080"
echo "PID: $(cat server.pid)"
echo "Logs: tail -f server.log"
echo "Stop: ./stop.sh"
echo "Access at: http://185.96.221.52:8080"
