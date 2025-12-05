# invite pseudocode
*implementation logic for inviting users*

## Database Changes

Add columns to users table:
- `invited_by` - user ID of who invited them (nullable for original users)
- `invited_at` - timestamp of when they were invited (nullable)
- `num_invites` - integer, number of invites remaining (default 0)

## API Functions

### Get invite count

```
function get_user_invites(device_id):
    user = get_user_by_device_id(device_id)
    if not user:
        return error("Not authenticated")

    return { "num_invites": user.num_invites }
```

### Create invite

```
function create_invite(inviter_device_id, invitee_name, invitee_email):
    # Get inviter's user ID
    inviter = get_user_by_device_id(inviter_device_id)
    if not inviter:
        return error("Not authenticated")

    # Check if inviter has invites remaining
    if inviter.num_invites <= 0:
        return error("No invites remaining")

    # Normalize email
    email = invitee_email.lower().strip()

    # Check if user already exists
    existing_user = get_user_by_email(email)

    if existing_user:
        return {
            "status": "already_exists",
            "user_name": existing_user.name,
            "testflight_link": get_testflight_link()
        }

    # Create new user with invited status
    new_user_id = create_user_from_invite(
        email = email,
        name = invitee_name,
        invited_by = inviter.id,
        invited_at = now()
    )

    # Decrement inviter's invite count
    update_user(inviter.id, num_invites = inviter.num_invites - 1)

    testflight_link = get_testflight_link()
    invite_message = "Hi " + invitee_name + "! I'd like you to try microclub.\nDownload it here: " + testflight_link

    return {
        "status": "invite_created",
        "testflight_link": testflight_link,
        "invite_message": invite_message
    }
```

### Get TestFlight link

```
function get_testflight_link():
    return config.TESTFLIGHT_URL or "https://testflight.apple.com/join/StN3xAMy"
```

## Client Functions

### Fetch invite count

```
function fetch_invite_count():
    response = GET /api/user/invites?device_id=device_id
    num_invites = response.num_invites
    # Update UI - show/hide invite button based on count
```

### Show invite modal

```
function show_invite_modal():
    # Display modal with name and email fields
    # On submit, call create_invite API
    # Show success screen with copyable message
    # On dismiss, refresh invite count
```

### Handle invite response

```
function handle_invite_response(response):
    if response.status == "already_exists":
        show_message("Already signed up: " + response.user_name)

    else if response.status == "invite_created":
        show_success_screen(
            testflight_link: response.testflight_link,
            invite_message: response.invite_message
        )
```

### Success screen

```
function show_success_screen(testflight_link, invite_message):
    # Show "Invite created!"
    # Show the invite message text
    # "Copy Message" button copies invite_message to clipboard
    # "Done" button dismisses
```

## Patching Instructions

**Server (Python):**
- Add `invited_by`, `invited_at`, `num_invites` columns to users table
- Add `GET /api/user/invites` endpoint to return invite count
- Add `POST /api/invite` endpoint with invite count check and decrement
- Modify `create_user` to accept name, invited_by, invited_at params

**Client (iOS):**
- Add `numInvites` state and `fetchInviteCount()` function to ContentView
- Show "invite friend" button only when `numInvites > 0`
- Refresh invite count on app load and when invite sheet dismisses
- Update InviteSheet to have name + email fields
- Add success screen with copyable message
- Add clipboard copy functionality
