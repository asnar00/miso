#!/bin/bash
# Run all tests for iOS client

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/test-results.log"
PROJECT="NoobTest.xcodeproj"
SCHEME="NoobTest"
SIMULATOR="platform=iOS Simulator,name=iPhone 17 Pro"

echo "" | tee "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Running ALL Firefly iOS Client Tests" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"

cd "$SCRIPT_DIR"

# Check if test target exists
if ! xcodebuild -project "$PROJECT" -list | grep -q "NoobTestTests"; then
    echo "❌ Test target not found!" | tee -a "$LOG_FILE"
    echo "Please follow TESTING_SETUP.md to add the test target to Xcode" | tee -a "$LOG_FILE"
    exit 1
fi

# Run all tests
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$SIMULATOR" \
    -enableCodeCoverage YES \
    LD="clang" \
    2>&1 | tee -a "$LOG_FILE"

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
