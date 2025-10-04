# Deployment
*Firefly server deployment configuration*

Deployment configuration for the Firefly Flask server.

## Server Environment

- **Hardware**: Mac mini
- **Local IP**: 192.168.1.76
- **Public IP**: 185.96.221.52
- **Operating System**: macOS
- **Python**: 3.x
- **Framework**: Flask

## Server Location

The server code is located at:
```
firefly/product/server/py/
```

Contains:
- `app.py` - Main Flask application
- `requirements.txt` - Python dependencies

## Running the Server

See `miso/platforms/py/flask-deployment.md` for detailed Flask deployment instructions.

### Quick Start

Development mode:
```bash
cd firefly/product/server/py
python3 app.py
```

Background mode:
```bash
cd firefly/product/server/py
nohup python3 app.py > server.log 2>&1 &
```

## Current Status

The Firefly server is currently running:
- **Mode**: Development (Flask built-in server)
- **Debug**: Enabled
- **URL**: http://185.96.221.52:8080
- **Access**: Public (via port forwarding)

See `server/network.md` for network configuration details.

## Production Upgrade Path

When ready for production:
1. Use gunicorn instead of Flask dev server
2. Add HTTPS/TLS encryption
3. Implement authentication/authorization
4. Add rate limiting
5. Set up proper logging and monitoring
6. Use environment variables for configuration
