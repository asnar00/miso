# post notifications - pseudocode
*checking for new posts by other users*

Post badge checking is handled by the unified notifications endpoint. See `infrastructure/notifications/pseudocode.md` for the main implementation.

## How It Works

1. Client stores `last_viewed_posts` timestamp locally
2. Unified poll endpoint receives this timestamp and current user's email
3. Server checks for posts where:
   - `template_name = 'post'`
   - `created_at > last_viewed_posts`
   - `user_id != current_user_id` (not the current user's posts)
4. Returns `has_new_posts: true/false` in response
5. Client updates badge state

## Server Query

```sql
SELECT COUNT(*) FROM posts p
JOIN users u ON p.user_id = u.id
WHERE p.template_name = 'post'
AND p.created_at > %s
AND u.email != %s
```

## Badge Clearing

When user taps Posts tab:
```
hasPostsBadge = false
Storage.set("last_viewed_posts", now().isoString)
```

Next poll will find no new posts since the updated timestamp.
