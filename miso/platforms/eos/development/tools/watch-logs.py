#!/usr/bin/env python3
"""
Real-time Android log viewer
Streams logs from connected Android device via ADB and displays only app log messages

CONFIGURATION: Set your package name below
"""

import subprocess
import sys
import re
import os
from datetime import datetime

# ============================================================================
# CONFIGURE THIS: Set your app package name
# ============================================================================
PACKAGE_NAME = "com.miso.noobtest"  # Change this to your package name

def main():
    """Stream logs from Android device in real-time"""
    # Log file path in current directory
    log_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "device-logs.txt")

    print(f"📱 Watching logs from {PACKAGE_NAME}...")
    print(f"📝 Writing to: {log_file_path}\n")

    # Clear logcat buffer
    subprocess.run(['adb', 'logcat', '-c'], capture_output=True)

    # Stream logs from device using adb logcat
    # -v brief: Use brief format (default, shows level/tag(PID): message)
    cmd = ['adb', 'logcat', '-v', 'brief']

    try:
        # Open log file for writing
        with open(log_file_path, 'w') as log_file:
            log_file.write(f"# Android logs from {PACKAGE_NAME}\n")
            log_file.write(f"# Started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

            # Start log streaming process
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,  # Line buffered
                universal_newlines=True
            )

            print("Streaming logs (Ctrl+C to stop):\n")

            # Read and filter log lines
            for line in process.stdout:
                line = line.strip()

                # Only show lines with our package name AND [APP] prefix (our custom logs only)
                if PACKAGE_NAME in line and '[APP]' in line:
                    # Parse logcat line (format: "I/Tag(PID): message")
                    match = re.match(r'([VDIWEF])/([^(]+)\(\s*\d+\):\s*(.+)', line)
                    if match:
                        level = match.group(1)
                        tag = match.group(2).strip()
                        message = match.group(3)

                        # Strip [APP] prefix from message
                        message = message.replace('[APP] ', '')

                        # Map level to name
                        level_map = {
                            'V': 'VERBOSE',
                            'D': 'DEBUG',
                            'I': 'INFO',
                            'W': 'WARN',
                            'E': 'ERROR',
                            'F': 'FATAL'
                        }
                        level_name = level_map.get(level, level)

                        timestamp = datetime.now().strftime("%H:%M:%S")

                        # Format: timestamp [LEVEL] message
                        log_line = f"{timestamp} [{level_name}] {message}"

                        # Print to console
                        print(log_line)
                        sys.stdout.flush()

                        # Write to file
                        log_file.write(log_line + "\n")
                        log_file.flush()

    except KeyboardInterrupt:
        print("\n\n👋 Stopped watching logs")
        process.terminate()
        return 0
    except Exception as e:
        print(f"❌ Error streaming logs: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
