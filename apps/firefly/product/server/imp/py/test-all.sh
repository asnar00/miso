#!/bin/bash
# Run all tests for the Python server

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/test-results.log"

echo "" | tee "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Running ALL Firefly Server Tests" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "❌ pytest not found. Installing dependencies..." | tee -a "$LOG_FILE"
    pip3 install -r "$SCRIPT_DIR/requirements.txt"
fi

# Run all tests
cd "$SCRIPT_DIR"
pytest tests/test_features.py -v 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "======================================" | tee -a "$LOG_FILE"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!" | tee -a "$LOG_FILE"
else
    echo "❌ Some tests failed!" | tee -a "$LOG_FILE"
fi
echo "Results saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

exit $EXIT_CODE
