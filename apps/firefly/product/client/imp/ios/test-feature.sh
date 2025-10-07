#!/bin/bash
# Test a specific feature on iOS
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
PROJECT="NoobTest.xcodeproj"
SCHEME="NoobTest"
SIMULATOR="platform=iOS Simulator,name=iPhone 17 Pro"

echo "Testing iOS feature: $FEATURE" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"

cd "$SCRIPT_DIR"

# Check if test target exists
if ! xcodebuild -project "$PROJECT" -list | grep -q "NoobTestTests"; then
    echo "❌ Test target not found!" | tee -a "$LOG_FILE"
    echo "Please follow TESTING_SETUP.md to add the test target to Xcode" | tee -a "$LOG_FILE"
    exit 1
fi

# Run the specific feature tests
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$SIMULATOR" \
    -only-testing:"NoobTestTests/FeatureTests/test_${FEATURE}_serverResponds" \
    -only-testing:"NoobTestTests/FeatureTests/test_${FEATURE}_detectsServerRunning" \
    -only-testing:"NoobTestTests/FeatureTests/test_${FEATURE}_detectsServerDown" \
    LD="clang" \
    2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "======================================" | tee -a "$LOG_FILE"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Feature '$FEATURE' tests passed!" | tee -a "$LOG_FILE"
else
    echo "❌ Feature '$FEATURE' tests failed!" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

exit $EXIT_CODE
