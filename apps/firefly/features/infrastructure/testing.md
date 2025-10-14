# testing
*run feature tests remotely from your development machine*

Testing lets you verify that features work correctly by sending test commands from your Mac to the running app on your phone.

## How it works

Send a command like `test ping` to your phone, and it will:
1. Find and run the test for that feature
2. Report back "succeeded" or "failed because XXX"

You can test an entire feature tree with one command - `test firefly` would test all features and sub-features of firefly.

## Why this matters

Instead of manually checking if things work, you can automatically verify features while you develop. Tests run in the real app environment on the actual device, so they catch issues that simulators might miss.

## Communication

The app listens for test commands sent over the network. Your Mac sends the command, the phone runs the test, and you get an immediate result.

## Implementation

See `testing/imp/` for complete implementation details:
- **usage.md** - How to run tests from your Mac
- **ios.md** - iOS test infrastructure (TestServer, TestRegistry)
- **eos.md** - Android test infrastructure (TestServer, TestRegistry)
- **connection.md** - USB port forwarding setup
- **test-feature.sh** - Command-line tool for running tests
