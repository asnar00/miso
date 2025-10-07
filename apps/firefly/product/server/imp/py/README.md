# Firefly Server

*Flask server for the firefly social media platform*

## Implementation

This Python/Flask server implements the firefly server product.

Currently implements:
- **logo** - Displays the ᕦ(ツ)ᕤ logo on turquoise background in web browser
- **API endpoints** - Health check and remote shutdown

## Structure

```
py/
├── app.py              # Main Flask application
├── requirements.txt    # Python dependencies
├── start.sh           # Start server script
├── stop.sh            # Stop server script
├── remote-shutdown.sh # Remotely shutdown via API
└── README.md          # This file
```

## Setup

### First Time Setup

```bash
# Install Flask
pip3 install -r requirements.txt
```

### Starting the Server

```bash
./start.sh
```

The server will:
- Start on port 8080
- Be accessible at http://192.168.1.76:8080
- Run in background
- Log to `server.log`

### Stopping the Server

Locally:
```bash
./stop.sh
```

Remotely (from any machine on the network):
```bash
./remote-shutdown.sh
# Or use curl directly:
curl -X POST http://192.168.1.76:8080/api/shutdown
```

### Viewing Logs

```bash
tail -f server.log
```

## API Endpoints

### GET /
Returns HTML page with the noob logo on turquoise background

### GET /api/ping
Health check endpoint
```json
{
  "status": "ok",
  "message": "Firefly server is running"
}
```

### POST /api/shutdown
Shutdown the server remotely
```json
{
  "status": "shutting down",
  "message": "Server is shutting down"
}
```

## Deployment

Server is deployed on Mac mini at **192.168.1.76** (microservers-Mac-mini.local)

Access from:
- Local network: http://192.168.1.76:8080
- Mac mini itself: http://localhost:8080

## Implementation Notes

- Built from Python platform template at `miso/platforms/py/template/`
- Implements logo feature spec from `apps/firefly/features/logo.md`
- Uses turquoise color (#40E0D0) as specified
- Logo displayed at 120px font size
- Server runs on all interfaces (0.0.0.0) to be accessible from network
