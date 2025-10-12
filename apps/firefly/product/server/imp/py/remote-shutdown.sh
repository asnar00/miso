#!/bin/bash
# Remotely shutdown the Firefly server via API

curl -X POST http://185.96.221.52:8080/api/shutdown
echo ""
echo "Shutdown command sent to server"
