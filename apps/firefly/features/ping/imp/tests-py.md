# ping - Python Test Implementation
*pytest implementation for Flask /api/ping endpoint*

## Test Code

```python
import pytest
import json
import requests

# Test 1: Server Responds to Ping
def test_ping_serverResponds():
    """Test that /api/ping endpoint returns correct response"""
    server_url = "http://192.168.1.76:8080"

    try:
        response = requests.get(f"{server_url}/api/ping", timeout=5)

        # Verify HTTP 200
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"

        # Verify JSON response
        data = response.json()
        assert "status" in data, "Response should contain 'status' field"
        assert data["status"] == "ok", f"Expected status 'ok', got '{data['status']}'"
        assert "message" in data, "Response should contain 'message' field"

        print("✓ Server responds to ping correctly")

    except requests.exceptions.RequestException as e:
        pytest.fail(f"Request failed: {e}")

# Test 2: Client Detects Server Running
def test_ping_detectsServerRunning():
    """Test that we can successfully detect when server is reachable"""
    server_url = "http://192.168.1.76:8080"

    try:
        response = requests.get(f"{server_url}/api/ping", timeout=5)
        connection_success = (response.status_code == 200)

        assert connection_success, "Should detect server is running"
        print("✓ Successfully detected server running")

    except requests.exceptions.RequestException:
        pytest.fail("Should be able to connect to running server")

# Test 3: Client Detects Server Down
def test_ping_detectsServerDown():
    """Test that we can detect when server is unreachable"""
    # Use invalid port to simulate server down
    invalid_url = "http://192.168.1.76:9999"

    connection_failed = False
    try:
        response = requests.get(f"{invalid_url}/api/ping", timeout=2)
        if response.status_code != 200:
            connection_failed = True
    except requests.exceptions.RequestException:
        connection_failed = True

    assert connection_failed, "Should detect server is down"
    print("✓ Successfully detected server down")
```

## Dependencies

Add to `requirements.txt`:
```
pytest
requests
```

## Notes

- Tests use `requests` library for HTTP calls
- Test 1: Verifies Flask endpoint returns correct JSON
- Test 2: Verifies successful connection detection
- Test 3: Verifies failure detection (uses invalid port 9999)
- Tests 1 and 2 require server to be running
- Test 3 should pass regardless of server state
- 5 second timeout for real server, 2 seconds for failure test
