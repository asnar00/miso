#!/bin/bash
# Test a specific feature on the Python server
# Usage: ./test-feature.sh <feature-name>
# Example: ./test-feature.sh ping

if [ -z "$1" ]; then
    echo "Usage: ./test-feature.sh <feature-name>"
    echo "Example: ./test-feature.sh ping"
    exit 1
fi

FEATURE=$1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/test-results.log"

echo "Testing feature: $FEATURE" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "❌ pytest not found. Installing dependencies..." | tee -a "$LOG_FILE"
    pip3 install -r "$SCRIPT_DIR/requirements.txt"
fi

# Run the specific feature tests
cd "$SCRIPT_DIR"
pytest tests/test_features.py -k "test_${FEATURE}_" -v 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "======================================" | tee -a "$LOG_FILE"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Feature '$FEATURE' tests passed!" | tee -a "$LOG_FILE"
else
    echo "❌ Feature '$FEATURE' tests failed!" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

exit $EXIT_CODE
