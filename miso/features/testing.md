# testing
*automated tests ensure features work correctly*

Each feature can include automated tests that verify its behavior. Tests are written once per feature and run on each platform.

## Test Structure

For feature `A/B/C`, tests are specified in:
- `A/B/C/imp/tests.md` - what to test (natural language)
- `A/B/C/imp/tests-ios.md` - iOS test code
- `A/B/C/imp/tests-py.md` - Python test code
- `A/B/C/imp/tests-eos.md` - Android test code

## Running Tests

**Development loop** (single feature):
```bash
./test-feature.sh ping
```

**Pre-ship validation** (all tests):
```bash
./test-all.sh
```

## Example

The `ping` feature includes three tests:
1. Server responds to ping endpoint
2. Client detects server running
3. Client detects server down

When you run `./test-feature.sh ping`, all three tests execute and results are saved to `test-results.log`.

Tests provide fast feedback during development and ensure nothing breaks before shipping.
