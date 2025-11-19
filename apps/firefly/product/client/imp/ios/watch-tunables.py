#!/usr/bin/env python3
"""
Live Constants File Watcher

Watches live-constants.json for changes and automatically syncs to the device.
This enables a seamless workflow: edit the JSON file in any editor, and changes
are immediately reflected on the device.

Usage:
    python3 watch-tunables.py

Requirements:
    pip3 install watchdog requests
"""

import json
import time
import os
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class JSONWatcher(FileSystemEventHandler):
    def __init__(self, json_path, device_url):
        self.json_path = os.path.abspath(json_path)
        self.device_url = device_url
        print(f"👀 Watching {self.json_path}")
        print(f"📡 Device URL: {self.device_url}")
        # Sync initial state
        self.sync_to_device()

    def on_modified(self, event):
        # Check if the modified file is our JSON file
        if os.path.abspath(event.src_path) == self.json_path:
            print(f"\n📝 Detected change in {os.path.basename(self.json_path)}")
            self.sync_to_device()

    def sync_to_device(self):
        try:
            with open(self.json_path, 'r') as f:
                data = json.load(f)

            response = requests.post(
                f"{self.device_url}/tune",
                json=data,
                timeout=2
            )

            if response.status_code == 200:
                print(f"✅ Synced to device: {json.dumps(data, indent=2)}")
            else:
                print(f"❌ Server returned status {response.status_code}")

        except FileNotFoundError:
            print(f"❌ Error: File not found at {self.json_path}")
        except json.JSONDecodeError as e:
            print(f"❌ Error: Invalid JSON - {e}")
        except requests.exceptions.RequestException as e:
            print(f"❌ Error: Could not reach device - {e}")
        except Exception as e:
            print(f"❌ Unexpected error: {e}")

def main():
    # Configuration
    json_path = "../../live-constants.json"
    device_url = "http://localhost:8081"

    # Resolve absolute path for watching
    json_dir = os.path.dirname(os.path.abspath(json_path))

    # Create watcher
    watcher = JSONWatcher(json_path, device_url)

    # Set up file observer
    observer = Observer()
    observer.schedule(watcher, path=json_dir, recursive=False)
    observer.start()

    print(f"\n🔄 Auto-sync enabled. Edit the JSON file and changes will appear instantly!")
    print(f"Press Ctrl+C to stop watching.\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n\n👋 Stopping watcher...")
        observer.stop()

    observer.join()

if __name__ == "__main__":
    main()
