# notifications
*alerting users to new content via toolbar badges*

The notification system alerts users when new content is available by showing red badge dots on toolbar icons. This is a cross-cutting infrastructure feature that other features use to signal updates.

## Badge Display

Each toolbar button can show a notification badge - a small red dot (10pt diameter with 2pt white outline) at its top-right corner. The badge appears when there's new content the user hasn't seen yet.

## Unified Polling Endpoint

The client polls a single server endpoint every 5 seconds to check all notification types at once:

**Endpoint**: `POST /api/notifications/poll`

**Request**:
```json
{
    "user_email": "user@example.com",
    "query_ids": [1, 2, 3],
    "last_viewed_users": "2025-12-08T19:00:00Z",
    "last_viewed_posts": "2025-12-08T19:00:00Z"
}
```

**Response**:
```json
{
    "query_badges": {"1": true, "2": false, "3": true},
    "has_new_users": true,
    "has_new_posts": true
}
```

This single request returns all badge states, minimizing network overhead and battery usage.

## Timestamp Storage

- **Per-query timestamps**: Stored server-side in `query_views` table (user may have many queries)
- **Per-tab timestamps**: Stored client-side in local storage (one timestamp per content type)

When the user views content (e.g., taps the toolbar button), the local timestamp updates and the badge clears on the next poll.

## Current Notification Types

- **Posts badge** (speech bubble icon): New posts by other users - see `posts/notifications/spec.md`
- **Search badge** (magnifying glass icon): New matches on any saved search - see `posts/search/spec.md`
- **Users badge** (people icon): New user completed their profile - see `users/notifications/spec.md`

## Future: Push Notifications

The current polling approach works but isn't battery-efficient. A future enhancement would use APNs (Apple Push Notification service) to push updates instantly without polling. The badge logic remains the same - only the delivery mechanism changes.
