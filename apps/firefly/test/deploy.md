# deploy
*automated TestFlight deployment for the test application*

The test application can be automatically built, archived, and deployed to TestFlight using a deployment script.

## Deployment Process

1. **Build & Archive**: Compiles the app for iOS devices and creates an `.xcarchive`
2. **Export**: Packages the archive as a signed `.ipa` file
3. **Upload**: Sends the IPA to App Store Connect using API authentication
4. **TestFlight**: After processing (5-15 minutes), the build becomes available in TestFlight

## Authentication

Deployment uses App Store Connect API keys for secure, passwordless automation. API keys must be configured once as environment variables.

## Usage

```bash
cd apps/firefly/test/imp/ios
./deploy.sh
```

The script handles all steps automatically and provides status updates throughout the process.