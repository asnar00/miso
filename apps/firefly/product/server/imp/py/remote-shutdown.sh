#!/bin/bash
# Remotely shutdown the Firefly server via API

curl -X POST http://192.168.1.76:8080/api/shutdown
echo ""
echo "Shutdown command sent to server"
