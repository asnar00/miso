# Connection - Python/Flask Implementation
*Server-side implementation of the /api/ping health check endpoint*

## Implementation

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/ping', methods=['GET'])
def ping():
    return jsonify({
        'message': 'Firefly server is alive!',
        'status': 'ok'
    })
```

## Pseudocode

```
ROUTE /api/ping:
  METHOD: GET

  FUNCTION handle_ping():
    Create response object:
      message = "Firefly server is alive!"
      status = "ok"

    Return JSON response with status 200 OK
```

## Integration

This endpoint handler is registered with the Flask application at startup. When a GET request arrives at `/api/ping`, Flask routes it to the `ping()` function which returns a JSON response.

## Response Format

**Status Code**: 200 OK
**Content-Type**: application/json

```json
{
  "message": "Firefly server is alive!",
  "status": "ok"
}
```

## Testing

```bash
# Test locally
curl http://localhost:8080/api/ping

# Test from network
curl http://192.168.1.76:8080/api/ping

# Test from internet
curl http://185.96.221.52:8080/api/ping
```
