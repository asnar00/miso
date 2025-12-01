# invite
*inviting new users to join Firefly via TestFlight*

Users can invite friends to join Firefly by entering their email address. The system checks if the email already exists - if so, it shows the existing user's profile. If not, it records the pending invite and opens a share sheet with the TestFlight public link, allowing the inviter to send it via Messages, Email, WhatsApp, or any other sharing method.

## User Flow

1. User taps "Invite Friend" button (in Users tab)
2. Modal appears with email input field
3. User enters friend's email address
4. System checks if email exists in database:
   - **If exists**: Show "Already signed up!" message, add user to visible users list
   - **If doesn't exist**:
     - Save to pending_invites table
     - Show iOS share sheet with pre-filled message containing TestFlight link
     - User chooses how to share (Messages, Email, WhatsApp, etc.)

## Data Storage

Pending invites are tracked in the database:

```sql
CREATE TABLE pending_invites (
    id SERIAL PRIMARY KEY,
    inviter_user_id INTEGER REFERENCES users(id),
    invitee_email VARCHAR(255),
    invite_date TIMESTAMP DEFAULT NOW()
);
```

## API Endpoints

### Create Invite
```
POST /api/invite
Body: {
  "email": "friend@example.com"
}
Response: {
  "status": "already_exists" | "invite_created",
  "testflight_link": "https://testflight.apple.com/join/XXXXX",
  "user_id": 123  // only if already_exists
}
```

### Get TestFlight Link
```
GET /api/testflight-link
Response: {
  "link": "https://testflight.apple.com/join/XXXXX"
}
```

## UI Components

**InviteSheet** - Modal dialog with:
- Email input field
- "Send Invite" button
- Cancel button
- Loading state while checking email
- Success/error messages

**Share Sheet** - iOS native UIActivityViewController with:
- Pre-filled message: "Join me on Firefly! Download via TestFlight: [link]"
- TestFlight link
- User chooses sharing method

## TestFlight Link

The TestFlight public link works on both iOS and Android:
- **iOS users**: Opens in TestFlight app, allows installation
- **Android users**: Redirects to web page explaining the app (they'll need to wait for Android version or use web)
- **Web users**: Same as Android

## Notes

- No automated emails - users share personally for better conversion
- Pending invites are tracked but not enforced (anyone with link can join)
- When pending invitee signs up, their email matches and invite status can be updated (future enhancement)
- TestFlight allows up to 10,000 external testers
