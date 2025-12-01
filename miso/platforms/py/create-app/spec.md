# Create Flask App
*Creating a basic Flask web application from scratch*

Step-by-step guide to creating a new Flask application.

## Prerequisites

- Python 3.x installed
- pip package manager
- Text editor or IDE

## Quick Start

### 1. Create Project Directory

```bash
mkdir my-flask-app
cd my-flask-app
```

### 2. Create Virtual Environment (Optional but Recommended)

```bash
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
# venv\Scripts\activate   # On Windows
```

### 3. Install Flask

```bash
pip3 install flask
```

### 4. Create Requirements File

Create `requirements.txt`:
```
flask==3.0.0
```

This allows others to install dependencies:
```bash
pip3 install -r requirements.txt
```

### 5. Create Main Application File

Create `app.py`:
```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def index():
    return "Hello, World!"

@app.route('/api/status', methods=['GET'])
def status():
    return jsonify({
        'status': 'ok',
        'message': 'Server is running'
    })

if __name__ == '__main__':
    # Run on all interfaces (0.0.0.0) so it's accessible from network
    # Debug mode enables auto-reload and detailed error messages
    app.run(host='0.0.0.0', port=8080, debug=True)
```

### 6. Run the Application

```bash
python3 app.py
```

Server will start on `http://0.0.0.0:8080`

Test it:
```bash
curl http://localhost:8080/
curl http://localhost:8080/api/status
```

## Project Structure

### Minimal Structure
```
my-flask-app/
├── app.py              # Main application
└── requirements.txt    # Dependencies
```

### Expanded Structure
```
my-flask-app/
├── app.py              # Main application entry point
├── requirements.txt    # Dependencies
├── config.py           # Configuration settings
├── routes/             # Route handlers
│   ├── __init__.py
│   ├── api.py
│   └── web.py
├── models/             # Data models
│   └── __init__.py
├── static/             # Static files (CSS, JS, images)
└── templates/          # HTML templates (if using)
```

## Common Patterns

### Environment-Based Configuration

Create `config.py`:
```python
import os

class Config:
    DEBUG = os.getenv('DEBUG', 'False') == 'True'
    HOST = os.getenv('HOST', '0.0.0.0')
    PORT = int(os.getenv('PORT', 8080))
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')

class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False
```

Use in `app.py`:
```python
from flask import Flask
from config import DevelopmentConfig

app = Flask(__name__)
app.config.from_object(DevelopmentConfig)
```

### Organizing Routes with Blueprints

Create `routes/api.py`:
```python
from flask import Blueprint, jsonify

api = Blueprint('api', __name__, url_prefix='/api')

@api.route('/status')
def status():
    return jsonify({'status': 'ok'})

@api.route('/users')
def users():
    return jsonify({'users': []})
```

Register in `app.py`:
```python
from flask import Flask
from routes.api import api

app = Flask(__name__)
app.register_blueprint(api)
```

### Error Handling

```python
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500
```

### CORS Support (for web clients)

Install:
```bash
pip3 install flask-cors
```

Add to `requirements.txt`:
```
flask-cors==4.0.0
```

Use in `app.py`:
```python
from flask import Flask
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes
```

## Adding Features

To add new endpoints, define routes:

```python
@app.route('/api/endpoint', methods=['GET', 'POST'])
def endpoint_handler():
    if request.method == 'GET':
        return jsonify({'data': 'some data'})
    elif request.method == 'POST':
        data = request.get_json()
        return jsonify({'received': data}), 201
```

## Testing the App

### Manual Testing
```bash
# GET request
curl http://localhost:8080/api/status

# POST request with JSON
curl -X POST http://localhost:8080/api/endpoint \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

### Automated Testing

Install pytest:
```bash
pip3 install pytest
```

Create `test_app.py`:
```python
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_status(client):
    response = client.get('/api/status')
    assert response.status_code == 200
    assert response.json['status'] == 'ok'
```

Run tests:
```bash
pytest
```

## Next Steps

- See `flask-deployment.md` for deployment options
- See `miso/platforms/network.md` for making your app accessible from the internet
- Add database integration (SQLAlchemy, PostgreSQL, etc.)
- Add authentication (Flask-Login, JWT, etc.)
- Add API documentation (Swagger/OpenAPI)
- Implement logging and monitoring

## Common Issues

**Port already in use:**
```bash
lsof -ti:8080 | xargs kill
```

**Module not found:**
```bash
pip3 install flask
# Or with virtual environment active
```

**Can't access from other devices:**
- Make sure `host='0.0.0.0'` (not `127.0.0.1`)
- Check firewall settings
- For internet access, see network.md for port forwarding
