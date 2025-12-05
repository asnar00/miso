# version-check pseudocode
*implementation logic for build version checking*

## Server Side

### Configuration

```
LATEST_BUILD = <integer>
TESTFLIGHT_URL = <url string>
```

### API Endpoint

```
GET /api/version

function get_version():
    return {
        "latest_build": config.LATEST_BUILD,
        "testflight_url": config.TESTFLIGHT_URL
    }
```

## Client Side

### On App Launch

```
function check_version_on_launch():
    app_build = get_bundle_build_number()

    response = fetch("GET /api/version")
    server_build = response.latest_build
    testflight_url = response.testflight_url

    if app_build < server_build:
        show_update_required_modal(testflight_url)
```

### Update Required Modal

```
function show_update_required_modal(testflight_url):
    # Non-dismissable modal
    show_modal(
        title: "Update Available",
        message: "A new version of microclub is available. Please update to continue.",
        button: "Update Now",
        on_button_tap: open_url(testflight_url)
    )
```

## Patching Instructions

**Server:**
- Add `LATEST_BUILD` and `TESTFLIGHT_URL` to config/environment
- Add `/api/version` GET endpoint

**Client:**
- Add version check on app launch before showing main UI
- Create non-dismissable update modal view
- Get build number from app bundle
- Open TestFlight URL when button tapped

**Deployment:**
- The deployment script automatically updates LATEST_BUILD on the server after reading the confirmed build number from Apple's API
