#!/usr/bin/env python3
"""
Real-time iOS log viewer
Streams logs from connected iPhone via USB and displays only app log messages

CONFIGURATION: Set your app name below
"""

import subprocess
import sys
import re
import os
from datetime import datetime

# ============================================================================
# CONFIGURE THIS: Set your app name (should match your Xcode project name)
# ============================================================================
APP_NAME = "NoobTest"  # Change this to your app name

def main():
    """Stream logs from iPhone in real-time"""
    # Log file path in current directory
    log_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "device-logs.txt")

    print(f"📱 Watching logs from {APP_NAME}...")
    print(f"📝 Writing to: {log_file_path}\n")

    # Stream logs from device using pymobiledevice3
    cmd = ['pymobiledevice3', 'syslog', 'live']

    # Pattern to match OUR app log messages with [APP] prefix
    # Format: timestamp AppName{subsystem}[pid] <LEVEL>: [APP] message
    log_pattern = re.compile(rf'{APP_NAME}\{{[^}}]+\}}\[\d+\] <(DEBUG|INFO|NOTICE|WARNING|ERROR|FAULT)>: \[APP\] (.+)')

    try:
        # Open log file for writing
        with open(log_file_path, 'w') as log_file:
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

                # Only show lines with [APP] prefix (our explicit log calls)
                match = log_pattern.search(line)
                if match:
                    level = match.group(1)
                    message = match.group(2)
                    timestamp = datetime.now().strftime("%H:%M:%S")

                    # Format: timestamp [LEVEL] message
                    log_line = f"{timestamp} [{level}] {message}"

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
