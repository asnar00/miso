#!/bin/bash
# Send command to viewer app
echo "goto $1" > /Users/asnaroo/Desktop/experiments/miso/viewer_command.txt
echo "Command sent: goto $1"
echo "File contents:"
cat /Users/asnaroo/Desktop/experiments/miso/viewer_command.txt
echo "Waiting 2 seconds..."
sleep 2
echo "File still exists?" 
ls -la /Users/asnaroo/Desktop/experiments/miso/viewer_command.txt 2>/dev/null || echo "File was consumed!"