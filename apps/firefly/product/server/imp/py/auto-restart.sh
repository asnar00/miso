#!/bin/bash
# Auto-restart script triggered by /api/restart endpoint
# This runs in the background and restarts the server after shutdown

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Wait 2 seconds for the HTTP response to be sent
echo "$(date) - Waiting for response to be sent..." >> auto-restart.log
sleep 2

# Forcefully stop the server
echo "$(date) - Stopping server..." >> auto-restart.log
./stop.sh >> auto-restart.log 2>&1
sleep 1

# Check if PostgreSQL is running, restart if needed
if ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo "$(date) - PostgreSQL not responding, restarting..." >> auto-restart.log
    /opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start
    sleep 2
fi

# Start the server
echo "$(date) - Starting server..." >> auto-restart.log
./start.sh >> auto-restart.log 2>&1

echo "$(date) - Server restart complete" >> auto-restart.log
