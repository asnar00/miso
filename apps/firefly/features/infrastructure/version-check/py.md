# version-check Python implementation

## Configuration

Add to `.env`:
```
LATEST_BUILD=17
TESTFLIGHT_URL=https://testflight.apple.com/join/StN3xAMy
```

Add to `.env.example`:
```
# Version Check Configuration
# Update LATEST_BUILD after each TestFlight deployment
LATEST_BUILD=16
TESTFLIGHT_URL=https://testflight.apple.com/join/XXXXX
```

## app.py

Add endpoint:
```python
@app.route('/api/version', methods=['GET'])
def get_version():
    """Return latest build number for version checking"""
    latest_build = int(config.get_config_value('LATEST_BUILD') or '0')
    testflight_url = config.get_config_value('TESTFLIGHT_URL') or 'https://testflight.apple.com/join/XXXXX'
    return jsonify({
        'latest_build': latest_build,
        'testflight_url': testflight_url
    })
```

## Automatic Updates

The `testflight-deploy.py` script automatically updates `LATEST_BUILD` on the server after each successful deployment:

1. Reads confirmed build number from Apple's App Store Connect API
2. SSHs to server and updates `.env` file
3. Restarts server to pick up new config
4. Verifies by calling `/api/version`

This ensures the server always reports the correct latest build without manual intervention.
