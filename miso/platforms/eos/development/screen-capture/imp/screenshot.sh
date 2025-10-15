#!/bin/bash
# Screenshot just the Android display from the scrcpy window
# Usage: ./screenshot.sh [output_filename]

# Default output filename with timestamp
OUTPUT="${1:-android_screenshot_$(date +%Y%m%d_%H%M%S).png}"

# Get the process ID of scrcpy
SCRCPY_PID=$(pgrep -x "scrcpy" | head -1)

if [ -z "$SCRCPY_PID" ]; then
    echo "Error: scrcpy is not running"
    echo "Please start it first with: python3 android_screencap.py"
    exit 1
fi

echo "Found scrcpy (PID: $SCRCPY_PID)"

# Bring window to front and get its bounds using AppleScript
# Look for window titled "Android Screen" or any scrcpy window
WINDOW_BOUNDS=$(osascript <<EOF
tell application "System Events"
    try
        -- Try to find scrcpy window by title or process
        set scrcpyProcess to first process whose name is "scrcpy"

        -- Bring the process to front
        set frontmost of scrcpyProcess to true

        -- Small delay to ensure window is brought to front
        delay 0.2

        set targetWindow to first window of scrcpyProcess
        set windowPosition to position of targetWindow
        set windowSize to size of targetWindow
        set x to item 1 of windowPosition
        set y to item 2 of windowPosition
        set w to item 1 of windowSize
        set h to item 2 of windowSize
        return (x as string) & "," & (y as string) & "," & (w as string) & "," & (h as string)
    on error errMsg
        return "ERROR:" & errMsg
    end try
end tell
EOF
)

if [[ "$WINDOW_BOUNDS" == ERROR:* ]]; then
    echo "Error: Could not get window bounds: ${WINDOW_BOUNDS#ERROR:}"
    exit 1
fi

# Parse the bounds
IFS=',' read -r X Y W H <<< "$WINDOW_BOUNDS"

echo "Window bounds: x=$X y=$Y w=$W h=$H"

# The Android display is typically in the center of the window with some chrome
# scrcpy has title bar (~28px on macOS) and minimal padding around the display
TITLE_BAR=28
PADDING=1  # scrcpy has very minimal padding

# Calculate the Android display rectangle
DISPLAY_X=$((X + PADDING))
DISPLAY_Y=$((Y + TITLE_BAR + PADDING))
DISPLAY_W=$((W - 2 * PADDING))
DISPLAY_H=$((H - TITLE_BAR - 2 * PADDING))

echo "Capturing Android display: x=$DISPLAY_X y=$DISPLAY_Y w=$DISPLAY_W h=$DISPLAY_H"

# Capture the specific region using -R flag
# -R captures a rectangle: x,y,width,height
screencapture -R"$DISPLAY_X,$DISPLAY_Y,$DISPLAY_W,$DISPLAY_H" -x "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "✓ Screenshot saved to: $OUTPUT"
else
    echo "Error: Failed to capture screenshot"
    exit 1
fi
