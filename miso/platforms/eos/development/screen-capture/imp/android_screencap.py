#!/usr/bin/env python3
"""
Android Screen Capture with Console
Launches scrcpy for screen mirroring and provides a console window for live logs
"""

import subprocess
import tkinter as tk
from tkinter import scrolledtext
import threading
import sys
import re
import time
from datetime import datetime

# ============================================================================
# CONFIGURATION: Set your app package name
# ============================================================================
PACKAGE_NAME = "com.miso.noobtest"  # Change this to your app package

class ConsoleWindow:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Android Console")
        self.root.geometry("500x844+800+100")  # Position to right of typical scrcpy window

        # Console text widget
        self.console = scrolledtext.ScrolledText(
            self.root,
            wrap=tk.WORD,
            width=60,
            height=50,
            bg="#1a1a1a",
            fg="#00ff00",
            font=("Courier", 10),
            insertbackground="#00ff00"
        )
        self.console.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # Control frame
        control_frame = tk.Frame(self.root, bg="#2a2a2a")
        control_frame.pack(fill=tk.X, padx=5, pady=5)

        # Clear button
        clear_btn = tk.Button(
            control_frame,
            text="Clear",
            command=self.clear_console,
            bg="#3a3a3a",
            fg="white",
            padx=10
        )
        clear_btn.pack(side=tk.LEFT, padx=5)

        # Status label
        self.status_label = tk.Label(
            control_frame,
            text=f"Monitoring: {PACKAGE_NAME}",
            bg="#2a2a2a",
            fg="#00ff00",
            font=("Courier", 10)
        )
        self.status_label.pack(side=tk.LEFT, padx=10)

        # Log file path
        self.log_file_path = "/Users/asnaroo/Desktop/experiments/miso/miso/platforms/eos/development/screen-capture/imp/device-logs.txt"

        # Start log streaming
        self.log_thread = None
        self.running = True

        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

    def clear_console(self):
        self.console.delete(1.0, tk.END)

    def append_log(self, message):
        """Append log message to console and file"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_line = f"{timestamp} {message}\n"

        # Update GUI
        self.console.insert(tk.END, log_line)
        self.console.see(tk.END)

        # Write to file
        try:
            with open(self.log_file_path, 'a') as f:
                f.write(log_line)
        except Exception as e:
            print(f"Error writing to log file: {e}")

    def stream_logs(self):
        """Stream logs from adb logcat filtered by package"""
        # Clear logcat buffer
        subprocess.run(['adb', 'logcat', '-c'], capture_output=True)

        # Start logcat filtered by package
        cmd = ['adb', 'logcat', '-v', 'brief']

        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )

            for line in process.stdout:
                if not self.running:
                    process.terminate()
                    break

                # Filter for [APP] prefix (our custom logs only)
                # Check for package name OR MisoLogger tag
                if '[APP]' in line and ('MisoLogger' in line or PACKAGE_NAME in line):
                    # Parse logcat line (format: "I/Tag(PID): message")
                    match = re.match(r'([VDIWEF])/([^(]+)\(\s*\d+\):\s*(.+)', line.strip())
                    if match:
                        level = match.group(1)
                        tag = match.group(2).strip()
                        message = match.group(3)

                        # Strip [APP] prefix from message
                        message = message.replace('[APP] ', '')

                        # Map level to name
                        level_map = {'V': 'VERBOSE', 'D': 'DEBUG', 'I': 'INFO',
                                   'W': 'WARN', 'E': 'ERROR', 'F': 'FATAL'}
                        level_name = level_map.get(level, level)

                        log_msg = f"[{level_name}] {message}"
                        self.append_log(log_msg)

        except Exception as e:
            self.append_log(f"ERROR: Log streaming failed: {e}")

    def start_logging(self):
        """Start log streaming in background thread"""
        # Initialize log file
        try:
            with open(self.log_file_path, 'w') as f:
                f.write(f"# Android logs from {PACKAGE_NAME}\n")
                f.write(f"# Started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        except Exception as e:
            print(f"Warning: Could not initialize log file: {e}")

        self.log_thread = threading.Thread(target=self.stream_logs, daemon=True)
        self.log_thread.start()

        self.append_log(f"Started monitoring logs from {PACKAGE_NAME}")
        self.append_log(f"Writing to: {self.log_file_path}")

    def on_closing(self):
        """Handle window close"""
        self.running = False
        self.root.destroy()

    def run(self):
        """Run the Tkinter main loop"""
        self.start_logging()
        self.root.mainloop()


def check_device():
    """Check if Android device is connected"""
    try:
        result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True,
            timeout=5
        )

        lines = result.stdout.strip().split('\n')[1:]  # Skip header
        devices = [line for line in lines if line.strip() and 'device' in line]

        if not devices:
            print("❌ No Android device connected")
            print("   1. Connect your device via USB")
            print("   2. Enable USB debugging")
            print("   3. Accept authorization prompt on device")
            return False

        device_id = devices[0].split()[0]
        print(f"✅ Found device: {device_id}")
        return True

    except Exception as e:
        print(f"❌ Error checking device: {e}")
        return False


def launch_scrcpy():
    """Launch scrcpy for screen mirroring"""
    print("📱 Launching scrcpy for screen mirroring...")

    # scrcpy options:
    # --window-title: Set window title
    # --window-x, --window-y: Position window
    # --stay-awake: Keep device awake while connected
    # --turn-screen-off: Turn off device screen (optional)

    try:
        scrcpy_process = subprocess.Popen(
            [
                'scrcpy',
                '--window-title', 'Android Screen',
                '--window-x', '100',
                '--window-y', '100',
                '--stay-awake'
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        print("✅ scrcpy launched")
        return scrcpy_process

    except Exception as e:
        print(f"❌ Failed to launch scrcpy: {e}")
        print("   Install with: brew install scrcpy")
        return None


def main():
    """Main entry point"""
    print("🚀 Android Screen Capture with Console")
    print(f"   Package: {PACKAGE_NAME}\n")

    # Check device
    if not check_device():
        sys.exit(1)

    # Launch scrcpy
    scrcpy_process = launch_scrcpy()
    if not scrcpy_process:
        sys.exit(1)

    # Give scrcpy a moment to start
    time.sleep(1)

    # Launch console window
    print("📺 Launching console window...")
    console = ConsoleWindow()

    try:
        console.run()
    finally:
        # Cleanup
        if scrcpy_process:
            scrcpy_process.terminate()
        print("\n👋 Shutting down")


if __name__ == '__main__':
    main()
