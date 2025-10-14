# Storage Tests

*Verify local storage functionality*

## Test: storage

Verifies that storage can:
1. Save key-value pairs
2. Retrieve saved values
3. Clear values
4. List all stored keys

## Test implementation

```
function testStorage() -> TestResult
    // Save test data
    storage.set("test_key_1", "test_value_1")
    storage.set("test_key_2", "test_value_2")
    storage.set("test_number", 42)
    storage.set("test_bool", true)

    // Retrieve and verify
    if storage.get("test_key_1") != "test_value_1":
        return TestResult(success: false, error: "Failed to retrieve test_key_1")

    if storage.get("test_number") != 42:
        return TestResult(success: false, error: "Failed to retrieve test_number")

    if storage.get("test_bool") != true:
        return TestResult(success: false, error: "Failed to retrieve test_bool")

    // List all keys
    keys = storage.listKeys()
    if not keys.contains("test_key_1"):
        return TestResult(success: false, error: "test_key_1 not in keys list")

    // Clear test data
    storage.remove("test_key_1")
    storage.remove("test_key_2")
    storage.remove("test_number")
    storage.remove("test_bool")

    // Verify cleared
    if storage.get("test_key_1") != null:
        return TestResult(success: false, error: "Failed to clear test_key_1")

    return TestResult(success: true)
```

## Expected behavior

- All values should be retrievable after saving
- Keys should appear in the list
- Values should be gone after removal
- Test cleans up after itself
