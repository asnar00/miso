# explore-tree implementation (pseudocode)

## Overview

Display a play button (▶︎) on expanded posts that have children, positioned on the right edge of the post container. Tapping this button currently logs to console (placeholder for future tree navigation).

## Server Changes

### Database: get_recent_posts (updated)

**Purpose**: Include child count with each post for efficient UI rendering.

**Changes**: Modified SQL query to LEFT JOIN with posts table on parent_id and COUNT children per post.

**Query**:
```sql
SELECT p.*, u.email as author_name, COUNT(children.id) as child_count
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN posts children ON children.parent_id = p.id
GROUP BY p.id, u.email
```

**Result**: Each post now includes `child_count` field (integer, 0 if no children).

## iOS Client Changes

### Post Model

**Added field**: `childCount: Int?`

**Purpose**: Store number of children for each post, used to determine button visibility.

### UI Component: PostCardView

**Button specs**:
- Only visible when post is expanded AND childCount > 0
- White circular background (32x32 points)
- Black play icon (`play.fill` SF Symbol, size 14)
- Positioned 16 points right of container (overlaps edge)
- Drop shadow for depth

**Button action**: Calls `viewChildren()` function which logs:
```
[PostCardView] View children button tapped for post {id}: {title}
```

**Implementation location**: Within ZStack wrapping the post card, aligned .trailing

## Future Enhancement

The `viewChildren()` function is a placeholder. Future implementation will:
- Navigate to child posts view
- Display tree structure
- Allow drilling down through post hierarchy
