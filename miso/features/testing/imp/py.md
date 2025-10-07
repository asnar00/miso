# testing - Python Implementation
*Python/pytest testing details*

## Overview

Python tests use pytest framework and can run against local or remote servers.

## Setup Requirements

**Auto-setup**: Dependencies are automatically installed when running tests

The test scripts check for pytest and install requirements if needed:
```bash
pip3 install -r requirements.txt
```

## Test File Structure

**Product test file**: `apps/product/server/imp/py/tests/test_features.py`

```python
import pytest
import requests

# Feature: ping
def test_ping_serverResponds():
    # Generated from features/ping/imp/tests-py.md
    pass

def test_ping_detectsServerRunning():
    # Generated from features/ping/imp/tests-py.md
    pass

# Test runner
def test_all():
    # Calls all test functions
    pass
```

## Test Code Format

Feature tests in `features/name/imp/tests-py.md`:

```python
def test_featureName_scenario():
    """Test description"""
    server_url = "http://192.168.1.76:8080"

    try:
        response = requests.get(f"{server_url}/api/endpoint", timeout=5)

        assert response.status_code == 200
        assert condition, "Failure message"

        print("✓ Test passed")

    except requests.exceptions.RequestException as e:
        pytest.fail(f"Request failed: {e}")
```

## Running Tests

### Single Feature

```bash
cd apps/product/server/imp/py
./test-feature.sh featureName
```

Executes:
```bash
pytest tests/test_features.py -k "test_featureName_" -v
```

### All Tests

```bash
cd apps/product/server/imp/py
./test-all.sh
```

Executes:
```bash
pytest tests/test_features.py -v
```

## Key Details

**Test Runner**: pytest
**Test Framework**: pytest with assertions
**HTTP Library**: requests
**Execution Environment**: Local machine (tests remote server)
**Timeout**: Configurable per request (typically 5s)
**Assertions**: Standard Python assert statements

## Test Results

Results are:
- Streamed to console in real-time
- Saved to `test-results.log`
- Include pass/fail status for each test
- Show execution time (typically ~0.2s per test)

## Dependencies

From `requirements.txt`:
```
flask==3.0.0
pytest
requests
```

Auto-installed by test scripts if missing.

## Example: ping Feature

From `apps/firefly/features/ping/imp/tests-py.md`:

```python
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

        print("✓ Server responds to ping correctly")

    except requests.exceptions.RequestException as e:
        pytest.fail(f"Request failed: {e}")
```

Generated into: `apps/firefly/product/server/imp/py/tests/test_features.py`

Run with: `./test-feature.sh ping`

Output:
```
============================= test session starts ==============================
tests/test_features.py::test_ping_serverResponds PASSED                  [ 33%]
tests/test_features.py::test_ping_detectsServerRunning PASSED            [ 66%]
tests/test_features.py::test_ping_detectsServerDown PASSED               [100%]
======================= 3 passed, 1 deselected in 0.18s ========================
✅ Feature 'ping' tests passed!
```

## Testing Against Remote Servers

Tests can target any server by changing the URL:
```python
server_url = "http://192.168.1.76:8080"  # Remote server
server_url = "http://localhost:8080"      # Local development
```

This allows testing deployed servers without running them locally.
