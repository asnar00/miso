# user notifications
*alerting when new users complete their profile*

When a new user completes their profile (taps "get started" and fills in their details), other users should see a red badge on the Users toolbar icon, indicating there's someone new to discover.

Uses the notification infrastructure defined in `infrastructure/notifications/spec.md`.

## When Badge Appears

The Users toolbar badge appears when:
- A user has completed their profile (`profile_complete = true`)
- That user's profile was completed after the current user last viewed the Users tab

## When Badge Clears

The badge clears when:
- User taps the Users toolbar button
- Client stores the current timestamp as "last viewed users"
- Next poll finds no new users since that timestamp

## Profile Completion

A profile is considered "complete" when the user:
1. Signs in successfully
2. Sees the welcome screen
3. Taps "get started"
4. Their profile post is created

At step 4, the server sets `profile_complete = true` and `profile_completed_at = NOW()` on their user record. This timestamp is what triggers the badge for other users.

## Notes

- The badge shows for ANY new completed profile, not just people invited by the current user
- This encourages discovery and community awareness
- Users who signed up but haven't completed their profile don't trigger badges
