# test connection
*how the Mac connects to the phone for testing*

## USB Port Forwarding

The test server runs on the phone on port 8081. Rather than discovering the phone's IP address, we use USB port forwarding to map `localhost:8081` on the Mac directly to the phone's test server.

## Setup

**Android (adb)**:
```bash
adb forward tcp:8081 tcp:8081
```

**iOS (pymobiledevice3)**:
```bash
# Forward port (daemonized - stays alive across multiple requests)
pymobiledevice3 usbmux forward -d 8081 8081
```

**Note**: The `-d` (daemonize) flag is required. Without it, the forwarder crashes after the first request.

## Using the connection

Once port forwarding is active, the Mac can send test commands to either device via:
```bash
curl http://localhost:8081/test/ping
```

The response will be either:
- `succeeded`
- `failed because <reason>`

## Benefits

- No need to discover phone IP address
- Works regardless of WiFi connectivity
- More secure (localhost only)
- Consistent interface for both platforms
- USB already connected for development

## In practice

Port forwarding should be set up automatically by development tools (install scripts, test runners). The user shouldn't need to manually configure it.
