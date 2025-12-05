# invite
*inviting new users to join microclub via TestFlight*

Users can invite friends to join microclub by entering their name and email address. The system creates a user record for the invitee (marked as "not yet logged in") and provides the inviter with a TestFlight link and message text they can copy into an email or message.

## Invite Limits

Each user has a limited number of invites (`num_invites` in database, default 0). The "invite friend" button only appears in the Users tab if the user has at least one invite remaining. After successfully inviting someone, the count is decremented by one.

## User Flow

1. User taps "invite friend" button (in Users tab) - only visible if invites remaining > 0
2. Modal appears with name and email input fields
3. User enters friend's name and email address
4. System checks if email exists in database:
   - **If exists**: Show "Already signed up!" message with the existing user's name
   - **If new**:
     - Create a user record with the name, email, and `logged_in = false`
     - Record who invited them and when
     - Decrement inviter's invite count
     - Show success screen with TestFlight link and copyable invite message

## Invite Success Screen

After a successful invite, show:
- "Invite sent!" confirmation
- The TestFlight link (tappable)
- Pre-written message text the inviter can copy:
  ```
  Hi [name]! I'd like you to try microclub.
  Download it here: [testflight link]
  ```
- "Copy Message" button that copies the text to clipboard
- "Done" button to dismiss

## Data Model

**Inviter's user record:**
- `num_invites` - number of invites remaining (decremented on each successful invite)

**New users created via invite have:**
- `name` - the name provided by the inviter
- `email` - their email address
- `logged_in` - set to `false` until they complete sign-in
- `invited_by` - the user ID of who invited them
- `invited_at` - when they were invited
- `num_invites` - set to 0 (new users start with no invites)

No profile post is created at invite time. The profile is created later when the invitee taps "get started" after signing in (see new-user feature).

When the invitee later signs in with that email, the existing user record is found and updated (rather than creating a new one).

## Notes

- No automated emails - the inviter personally sends the message for better conversion
- The TestFlight link works on iOS; Android users will see a web page
- When the invitee signs in, their `logged_in` flag becomes true
- The inviter's name appears as the referrer in the invitee's experience (future enhancement)
