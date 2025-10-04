# Python/Flask Server Implementation
*Flask-based HTTP server for Firefly backend*

## Overview

Minimal Flask server providing health check API endpoint for mobile app connectivity testing.

## Files

- **app.py**: Main Flask application with route handlers
- **requirements.txt**: Python package dependencies

## Setup

### Install Dependencies

```bash
pip install -r requirements.txt
```

Or install Flask directly:
```bash
pip install flask
```

### Run Server

```bash
python app.py
```

The server will start on `http://0.0.0.0:8080`

## Implementation Details

### Flask Application Structure

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/ping', methods=['GET'])
def ping():
    """Health check endpoint"""
    return jsonify({
        'message': 'Firefly server is alive!',
        'status': 'ok'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

### Key Components

**Flask Application**:
- `Flask(__name__)`: Creates the Flask app instance
- Automatically handles request routing, JSON serialization, HTTP headers

**Route Decorator**:
- `@app.route('/api/ping', methods=['GET'])`: Registers endpoint
- Maps HTTP GET requests to `/api/ping` → `ping()` function

**Response**:
- `jsonify()`: Flask helper that creates JSON response
- Automatically sets `Content-Type: application/json` header
- Returns HTTP 200 OK by default

**Server Configuration**:
- `host='0.0.0.0'`: Listen on all network interfaces (required for external access)
- `port=8080`: HTTP port
- `debug=True`: Development mode with auto-reload and detailed errors

## Testing

### Test Locally

```bash
curl http://localhost:8080/api/ping
```

### Test from Network

```bash
curl http://192.168.1.76:8080/api/ping
```

### Test from Internet

```bash
curl http://185.96.221.52:8080/api/ping
```

Expected response:
```json
{
  "message": "Firefly server is alive!",
  "status": "ok"
}
```

## Development Mode

Debug mode features:
- **Auto-reload**: Server restarts when code changes
- **Detailed errors**: Full stack traces in browser
- **Interactive debugger**: Pin-protected console in error pages

**Warning**: Never use `debug=True` in production (security risk)

## Production Deployment

For production use:

1. **Disable debug mode**: `app.run(host='0.0.0.0', port=8080, debug=False)`

2. **Use production WSGI server** (Flask's built-in server is not production-ready):
   ```bash
   pip install gunicorn
   gunicorn -w 4 -b 0.0.0.0:8080 app:app
   ```

3. **Add HTTPS**: Use reverse proxy (nginx) with TLS certificate

4. **Environment variables**: Externalize configuration
   ```python
   import os
   port = int(os.environ.get('PORT', 8080))
   debug = os.environ.get('DEBUG', 'False') == 'True'
   ```

5. **Logging**: Configure proper logging instead of print statements

## Extending the Server

Add new endpoints:

```python
@app.route('/api/users', methods=['GET'])
def get_users():
    return jsonify({
        'users': []
    })

@app.route('/api/users', methods=['POST'])
def create_user():
    data = request.get_json()
    # Process user creation
    return jsonify({'success': True}), 201
```

Add error handling:

```python
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500
```

## Dependencies

- **Flask 3.0.0**: Web framework
- **Werkzeug**: WSGI utility library (Flask dependency)
- **Jinja2**: Template engine (Flask dependency)
- **Python 3.8+**: Required Python version
