# version-check
*prompting users to update when a new build is available*

When the app starts, it checks with the server to see if a newer build is available. If the app's build number is lower than the server's latest build number, a modal appears prompting the user to update.

## How it works

1. The app knows its own build number
2. The server knows the latest build number
3. On app launch, the app asks the server for the latest build number
4. If the app's build is older, show an update prompt

## Update Prompt

A simple modal dialog appears with:
- Title: "Update Available"
- Message: "A new version of microclub is available. Please update to continue."
- Button: "Update Now" - opens TestFlight directly

The prompt is non-dismissable - users must update to continue using the app.

## Server Configuration

The server stores the latest build number. This is automatically updated by the deployment script after each successful upload - the script reads the confirmed build number from Apple and updates the server.

## Notes

- The TestFlight link opens the TestFlight app directly on the user's phone
- Build numbers are integers that increment with each release
- This ensures all testers stay on the same version during development
