# credentials
*setting up App Store Connect API keys for automated uploads*

API keys enable automated TestFlight uploads without passwords or 2FA prompts.

## Creating an API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Integrations** (not "People")
3. Click **"+"** to generate a new API Key
4. Name it (e.g., "CLI Upload")
5. Select **App Manager** access (gives upload permissions)
6. Click **"Generate"**
7. **Download the `.p8` file** (only chance to download!)
8. Note the **Key ID** and **Issuer ID** shown

## Storing Credentials Securely

### 1. Create secure directory
```bash
mkdir -p ~/.appstoreconnect/private_keys
chmod 700 ~/.appstoreconnect
```

### 2. Move API key file
```bash
mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/*.p8
```

### 3. Create config file

Create `~/.appstoreconnect/config`:

```bash
# App Store Connect API Configuration
# Created: 2025-09-30

export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_PYM5W2L9GV.p8"
export APP_STORE_CONNECT_API_KEY_ID="PYM5W2L9GV"
export APP_STORE_CONNECT_API_ISSUER_ID="2e5cbf08-b1a5-4857-b013-30fb6eec002e"
```

Replace values with your actual Key ID and Issuer ID.

```bash
chmod 600 ~/.appstoreconnect/config
```

### 4. Load credentials in shell

Add to `~/.zshrc`:

```bash
# App Store Connect API credentials
[ -f ~/.appstoreconnect/config ] && source ~/.appstoreconnect/config
```

Then reload:
```bash
source ~/.zshrc
```

## Using Credentials

The `altool` command automatically finds the `.p8` file in `~/.appstoreconnect/private_keys/`:

```bash
xcrun altool --upload-app \
    --type ios \
    --file MyApp.ipa \
    --apiKey $APP_STORE_CONNECT_API_KEY_ID \
    --apiIssuer $APP_STORE_CONNECT_API_ISSUER_ID
```

## Verifying Setup

```bash
echo "Key ID: ${APP_STORE_CONNECT_API_KEY_ID:0:3}..."
echo "Issuer ID: ${APP_STORE_CONNECT_API_ISSUER_ID:0:8}..."
echo "Key Path: $APP_STORE_CONNECT_API_KEY_PATH"
```

Should show partial values (not empty).

## Security Notes

- **Never commit** the `.p8` file or config to git
- The `.p8` file is your private key - treat like a password
- If compromised, revoke in App Store Connect and create new key
- Permissions (600/700) prevent other users from reading

## Implementation

See `credentials/imp/setup-credentials.sh` for interactive setup script.