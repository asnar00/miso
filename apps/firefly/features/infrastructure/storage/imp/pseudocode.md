# Storage Implementation

*Pseudocode for local data persistence*

## Key-Value Storage

Store simple data like login state:

```
function saveLoginState(email: String, isLoggedIn: Boolean)
    storage.set("user_email", email)
    storage.set("is_logged_in", isLoggedIn)

function getLoginState() -> (email: String?, isLoggedIn: Boolean)
    email = storage.get("user_email")
    isLoggedIn = storage.get("is_logged_in", default: false)
    return (email, isLoggedIn)

function clearLoginState()
    storage.remove("user_email")
    storage.remove("is_logged_in")
```

## App Initialization

Check storage on startup:

```
function onAppStart()
    (email, isLoggedIn) = getLoginState()

    if isLoggedIn and email exists:
        // User was logged in, go to main screen
        navigateToMainScreen(email)
    else:
        // Show login screen
        navigateToLoginScreen()
```

## Storage Keys

Standard keys used across the app:

- `user_email`: String - User's email address
- `is_logged_in`: Boolean - Whether user is currently logged in
- `device_id`: String - This device's unique identifier

(Future: add cache keys for posts, media paths, etc.)

## Clearing on Logout

```
function logout()
    clearLoginState()
    // Future: clear cached posts, media, etc.
    navigateToLoginScreen()
```
