# user notifications - pseudocode
*checking for new user profiles*

User badge checking is handled by the unified notifications endpoint. See `infrastructure/notifications/pseudocode.md` for the main implementation.

## How It Works

1. Client stores `last_viewed_users` timestamp locally
2. Unified poll endpoint receives this timestamp
3. Server checks for users with `profile_completed_at > last_viewed_users`
4. Returns `has_new_users: true/false` in response
5. Client updates badge state

## Database Requirements

Users table needs:
```sql
ALTER TABLE users ADD COLUMN profile_completed_at TIMESTAMP;
```

Set when profile is created:
```sql
UPDATE users SET profile_complete = TRUE, profile_completed_at = NOW() WHERE id = %s;
```

## Badge Clearing

When user taps Users tab:
```
hasUsersBadge = false
Storage.set("last_viewed_users", now().isoString)
```

Next poll will find no new users since the updated timestamp.
