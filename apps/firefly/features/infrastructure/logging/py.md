# Python/Flask Remote Logging Implementation

**File**: `apps/firefly/product/server/imp/py/app.py`

## Server Endpoints

### In-Memory Storage

Add to top of file after other global variables:

```python
# In-memory storage for device logs
# Structure: {deviceId: {"deviceName": str, "appVersion": str, "buildNumber": str, "logs": str, "tunables": dict, "timestamp": datetime}}
device_logs = {}
```

### POST /api/debug/logs

Receives log uploads from devices:

```python
@app.route('/api/debug/logs', methods=['POST'])
def upload_debug_logs():
    """Receive and store logs from a device"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        device_id = data.get('deviceId')
        if not device_id:
            return jsonify({"error": "Missing deviceId"}), 400

        # Store/update device logs
        device_logs[device_id] = {
            "deviceName": data.get('deviceName', 'Unknown'),
            "appVersion": data.get('appVersion', 'Unknown'),
            "buildNumber": data.get('buildNumber', 'Unknown'),
            "logs": data.get('logs', ''),
            "tunables": data.get('tunables', {}),
            "timestamp": datetime.now()
        }

        logger.info(f"[DebugLogs] Received logs from device {device_id} ({data.get('deviceName', 'Unknown')})")
        return jsonify({"status": "ok"}), 200

    except Exception as e:
        logger.error(f"[DebugLogs] Error receiving logs: {e}")
        return jsonify({"error": str(e)}), 500
```

### GET /api/debug/logs

List all devices that have uploaded logs:

```python
@app.route('/api/debug/logs', methods=['GET'])
def list_debug_logs():
    """List all devices that have uploaded logs"""
    devices = []
    for device_id, data in device_logs.items():
        devices.append({
            "deviceId": device_id,
            "deviceName": data["deviceName"],
            "appVersion": data["appVersion"],
            "buildNumber": data["buildNumber"],
            "timestamp": data["timestamp"].isoformat(),
            "logSize": len(data["logs"])
        })
    return jsonify(devices), 200
```

### GET /api/debug/logs/<deviceId>

Get full log data for a specific device:

```python
@app.route('/api/debug/logs/<device_id>', methods=['GET'])
def get_debug_logs(device_id):
    """Get logs for a specific device"""
    if device_id not in device_logs:
        return jsonify({"error": "Device not found"}), 404

    data = device_logs[device_id]
    return jsonify({
        "deviceId": device_id,
        "deviceName": data["deviceName"],
        "appVersion": data["appVersion"],
        "buildNumber": data["buildNumber"],
        "logs": data["logs"],
        "tunables": data["tunables"],
        "timestamp": data["timestamp"].isoformat()
    }), 200
```

## Usage

After deployment, you can check device logs via:

```bash
# List all devices with logs
curl http://185.96.221.52:8080/api/debug/logs

# Get logs for a specific device
curl http://185.96.221.52:8080/api/debug/logs/<deviceId>
```
