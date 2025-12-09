# post notifications
*alerting when other users make new posts*

When another user creates a new post (template_name='post'), the current user should see a red badge on the Posts toolbar icon (speech bubble), indicating there's new content to discover.

Uses the notification infrastructure defined in `infrastructure/notifications/spec.md`.

## When Badge Appears

The Posts toolbar badge appears when:
- A post with `template_name='post'` was created
- The post was created by a *different* user (not the current user)
- The post was created after the current user last viewed the Posts tab

## When Badge Clears

The badge clears when:
- User taps the Posts toolbar button
- Client stores the current timestamp as "last viewed posts"
- Next poll finds no new posts since that timestamp

## What Counts as a "Post"

Any post with `template_name='post'` triggers notifications:
- Regular posts ✓
- Replies to posts ✓
- Profile posts (template_name='profile') ✗
- Search queries (template_name='query') ✗

## Notes

- Users don't get notified about their own posts
- This encourages checking the feed for new content from the community
