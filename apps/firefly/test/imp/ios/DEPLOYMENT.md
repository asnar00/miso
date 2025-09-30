# TestFlight Deployment Guide

## One-Time Setup

### 1. Create App Store Connect API Key

This allows automated uploads without entering passwords.

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** > **Keys** tab
3. Click **+** to generate a new API Key
4. Give it a name (e.g., "CLI Upload") and select **Developer** access
5. Click **Generate**
6. **Download the `.p8` file** (you can only download once!)
7. Note the **Key ID** and **Issuer ID** shown on the page

### 2. Configure Environment Variables

Add these to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
# App Store Connect API credentials
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
export APP_STORE_CONNECT_API_KEY_ID="XXXXXXXXXX"
export APP_STORE_CONNECT_API_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Then reload your shell:
```bash
source ~/.zshrc  # or source ~/.bash_profile
```

### 3. Store the API Key File

```bash
mkdir -p ~/.appstoreconnect
mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/
chmod 600 ~/.appstoreconnect/AuthKey_*.p8
```

### 4. Create App Record in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** > **+** > **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: NoobTest (or your preferred name)
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select `com.miso.noobtest`
   - **SKU**: `noobtest` (or any unique identifier)
4. Click **Create**

## Deploying to TestFlight

Once setup is complete, deployment is a single command:

```bash
cd apps/firefly/test/imp/ios
./deploy.sh
```

The script will:
1. Clean previous builds
2. Archive the app for iOS devices
3. Export the archive as an IPA
4. Upload to App Store Connect
5. The build will automatically appear in TestFlight after processing (5-15 minutes)

## Manual Upload (if automation isn't configured)

If you haven't set up API keys, you can still upload manually:

```bash
cd apps/firefly/test/imp/ios
./deploy.sh  # This will create the IPA but skip upload
open -a 'Transporter' /tmp/NoobTestExport/NoobTest.ipa
```

Then sign in to Transporter with your Apple ID and click **Deliver**.

## Installing on Your iPhone via TestFlight

1. Install the **TestFlight** app from the App Store on your iPhone
2. After the build is processed in App Store Connect:
   - Go to **App Store Connect** > **TestFlight** tab
   - Add yourself as an internal tester
   - You'll receive an email invitation
3. Open the email on your iPhone and tap **View in TestFlight**
4. Install the app from TestFlight

## Troubleshooting

### "No signing certificate found"
Run: `./deploy.sh -allowProvisioningUpdates`

### "App hasn't been uploaded to TestFlight"
Check App Store Connect > **TestFlight** > **Builds** for processing status.

### "Authentication failed"
Verify your API key environment variables are set correctly:
```bash
echo $APP_STORE_CONNECT_API_KEY_ID
echo $APP_STORE_CONNECT_API_ISSUER_ID
echo $APP_STORE_CONNECT_API_KEY_PATH
```