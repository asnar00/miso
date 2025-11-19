#!/bin/bash
# Pre-demo health check and recovery script

SERVER_URL="http://185.96.221.52:8080"
SSH_HOST="microserver@185.96.221.52"

echo "=== Firefly Demo Health Check ==="
echo ""

# Check server health
echo "1. Checking server health..."
HEALTH=$(curl -s -w "\n%{http_code}" "$SERVER_URL/api/health")
HTTP_CODE=$(echo "$HEALTH" | tail -n1)
RESPONSE=$(echo "$HEALTH" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Server is healthy"
    echo "$RESPONSE" | python3 -m json.tool
else
    echo "❌ Server health check failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE"

    # Check if PostgreSQL is the issue
    echo ""
    echo "2. Checking PostgreSQL..."
    ssh $SSH_HOST "pg_isready -h localhost -p 5432"

    if [ $? -ne 0 ]; then
        echo "❌ PostgreSQL is not responding"
        echo ""
        echo "Attempting to restart PostgreSQL..."
        ssh $SSH_HOST "/opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 -l /opt/homebrew/var/log/postgresql@16.log start"
        sleep 3

        echo "Restarting server..."
        ssh $SSH_HOST "cd ~/firefly-server && ./stop.sh && ./start.sh"
        sleep 3

        echo ""
        echo "Re-checking health..."
        curl -s "$SERVER_URL/api/health" | python3 -m json.tool
    fi
fi

echo ""
echo "3. Checking recent posts..."
POSTS=$(curl -s "$SERVER_URL/api/posts/recent?limit=5")
POST_COUNT=$(echo "$POSTS" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
echo "✅ Found $POST_COUNT recent posts"

echo ""
echo "4. Checking search functionality..."
SEARCH=$(curl -s "$SERVER_URL/api/search?q=test&limit=5" 2>&1)
if echo "$SEARCH" | grep -q "error"; then
    echo "❌ Search returned error"
else
    echo "✅ Search is working"
fi

echo ""
echo "=== Demo Check Complete ==="
echo ""
echo "Quick recovery commands if needed during demo:"
echo "  ssh $SSH_HOST 'cd ~/firefly-server && ./stop.sh && ./start.sh'"
echo "  curl $SERVER_URL/api/health"
