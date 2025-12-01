# invite pseudocode
*natural-language implementation logic for inviting users*

## Database Schema

Add new table for tracking pending invites:

```sql
CREATE TABLE pending_invites (
    id SERIAL PRIMARY KEY,
    inviter_user_id INTEGER REFERENCES users(id),
    invitee_email VARCHAR(255) NOT NULL,
    invite_date TIMESTAMP DEFAULT NOW()
);
```

## API Functions

### Check if email exists and create invite

```
function create_invite(inviter_user_id, invitee_email):
    # Normalize email
    email = invitee_email.lower().strip()

    # Check if user already exists
    existing_user = query("SELECT id FROM users WHERE email = ?", email)

    if existing_user:
        return {
            "status": "already_exists",
            "user_id": existing_user.id,
            "testflight_link": get_testflight_link()
        }

    # Create pending invite
    query("INSERT INTO pending_invites (inviter_user_id, invitee_email) VALUES (?, ?)",
          inviter_user_id, email)

    return {
        "status": "invite_created",
        "testflight_link": get_testflight_link()
    }
```

### Get TestFlight public link

```
function get_testflight_link():
    # Return the TestFlight public link for external testing
    # This will be configured after getting link from App Store Connect
    return "https://testflight.apple.com/join/XXXXX"
```

## Client Functions

### Show invite sheet

```
function show_invite_sheet():
    # Display modal with email input field
    # On submit, call create_invite API
    # Handle response based on status
```

### Handle invite response

```
function handle_invite_response(response):
    if response.status == "already_exists":
        show_message("User already signed up!")
        # Optionally navigate to their profile

    else if response.status == "invite_created":
        # Open iOS share sheet with TestFlight link
        share_message = "Join me on Firefly! Download via TestFlight: " + response.testflight_link
        show_share_sheet(share_message)
```

### Show share sheet

```
function show_share_sheet(message):
    # iOS: Use UIActivityViewController
    # Show native share sheet with pre-filled message
    # User chooses how to share (Messages, Email, WhatsApp, etc.)
```

## Patching Instructions

**Server (Python):**
- Add `pending_invites` table to database schema
- Add `/api/invite` POST endpoint
- Add `/api/testflight-link` GET endpoint
- Store TestFlight link in configuration or environment variable

**Client (iOS):**
- Create `InviteSheet.swift` view with email input
- Update "Invite Friend" button in ContentView to show InviteSheet
- Implement share sheet using `UIActivityViewController`
- Add API calls for creating invite

**Client (Android):**
- Create equivalent invite dialog
- Implement Android share intent
- Add API calls for creating invite
