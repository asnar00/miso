#!/bin/bash
# Stop the Firefly server

if [ -f server.pid ]; then
    PID=$(cat server.pid)
    kill $PID 2>/dev/null
    rm server.pid
    echo "Firefly server stopped (PID: $PID)"
else
    # Try to find and kill by port
    lsof -ti:8080 | xargs kill 2>/dev/null
    echo "Firefly server stopped"
fi
