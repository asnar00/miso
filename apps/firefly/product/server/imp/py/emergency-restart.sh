#!/bin/bash
# Emergency recovery script for demo disasters

echo "🚨 EMERGENCY RESTART 🚨"
echo ""

ssh microserver@185.96.221.52 "
    echo 'Checking PostgreSQL...'
    if ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        echo 'Starting PostgreSQL...'
        /opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start
        sleep 2
    fi

    echo 'Restarting server...'
    cd ~/Desktop/nøøb/microclub/apps/firefly/product/server/imp/py
    ./stop.sh
    sleep 1
    ./start.sh
"

echo ""
echo "Waiting for server to stabilize..."
sleep 3

echo ""
echo "Testing health..."
curl -s http://185.96.221.52:8080/api/health | python3 -m json.tool

echo ""
echo "✅ Recovery complete"
