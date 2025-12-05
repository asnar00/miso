# logging
*multi-level logging system*

Logging occurs at three levels:

## local

Local logging lets us debug connection issues that occurred on mobile devices in the past. Log messages are stored in a local on-device file.

## connected

Connected logging sends real-time log messages to the host mac laptop (via USB cable) so that we can view them in real time.

## remote

Remote logging uploads the device's log file to the server periodically (every 60 seconds) so developers can view logs from devices they don't have physical access to.

Each device is identified by a unique device ID. The server stores the most recent log upload from each device, replacing any previous upload. Developers can view logs for any device by querying the server with the device ID.

The upload includes:
- Device ID (unique identifier for the device)
- Device name (user-visible name like "iPhone 12 mini")
- App version and build number
- The full contents of the local log file
- Current values of all tunables (for debugging configuration issues)
