# Server Connection
*Monitoring connectivity to the Firefly server*

The test app continuously checks connection status to the server during development.

## Connection Behaviour

The app monitors the server connection:
- Tests server connectivity every second
- Checks while app is active
- Uses the server's `/api/ping` endpoint for health checks
- Returns connection status (connected/disconnected)

## Server Endpoint

The app connects to the Firefly server at:
- **URL**: `http://185.96.221.52:8080/api/ping`
- **Protocol**: HTTP (with platform security exceptions configured)
- **Expected Response**: JSON with `status: "ok"`

This feature helps developers verify:
- Server is running and accessible
- Network connectivity is working
- App can communicate with backend services
