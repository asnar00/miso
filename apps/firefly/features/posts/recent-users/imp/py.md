# recent-users Python implementation

## Server Endpoint

Create a new endpoint `/api/users/recent` that fetches users ordered by their last_activity timestamp and returns their profile posts.

**File**: `apps/firefly/product/server/imp/py/app.py`

```python
@app.route('/api/users/recent', methods=['GET'])
def get_recent_users():
    """Get users ordered by most recent activity, with their profile posts"""
    try:
        users = db.get_recent_users()

        return jsonify({
            'status': 'success',
            'posts': users  # Return as 'posts' for compatibility with client
        })
    except Exception as e:
        print(f"Error getting recent users: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500
```

**Key decisions**:
- Endpoint path: `/api/users/recent`
- Return format matches `/api/posts/recent` for client compatibility
- Response uses 'posts' key even though we're returning profile posts
- No limit parameter needed (can add later if needed)

## Database Query

Add a new database method to fetch users with their profile posts, ordered by last_activity.

**File**: `apps/firefly/product/server/imp/py/db.py`

```python
def get_recent_users(self) -> List[Dict[str, Any]]:
    """Get users ordered by most recent activity, with their profile posts (parent_id = -1)"""
    conn = self.get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                       p.created_at, p.timezone, p.location_tag, p.ai_generated,
                       p.template_name,
                       t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                       COALESCE(u.name, u.email) as author_name,
                       u.email as author_email,
                       COUNT(children.id) as child_count
                FROM users u
                JOIN posts p ON p.user_id = u.id AND p.parent_id = -1
                LEFT JOIN templates t ON p.template_name = t.name
                LEFT JOIN posts children ON children.parent_id = p.id
                GROUP BY p.id, u.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body
                ORDER BY u.last_activity DESC
                """
            )
            return cur.fetchall()
    except Exception as e:
        print(f"Error getting recent users: {e}")
        return []
    finally:
        self.return_connection(conn)
```

**Key SQL decisions**:
- Start from `users` table and JOIN with `posts` where `parent_id = -1` (profile posts)
- Order by `u.last_activity DESC` to get most recently active users first
- Include child_count to show how many posts the user has
- Return same structure as `get_recent_posts()` for client compatibility
- Join with templates for placeholder support
- Join with children posts to get child_count

## Target Files

**Files to modify**:
1. `apps/firefly/product/server/imp/py/app.py`
   - Add new route `/api/users/recent` with `get_recent_users()` handler

2. `apps/firefly/product/server/imp/py/db.py`
   - Add new method `get_recent_users()` to Database class

## Testing

After deployment, test the endpoint:

```bash
curl http://185.96.221.52:8080/api/users/recent
```

Expected response:
```json
{
  "status": "success",
  "posts": [
    {
      "id": 123,
      "user_id": 456,
      "parent_id": -1,
      "title": "User Name",
      "summary": "User's profession or tagline",
      "body": "User's bio...",
      "image_url": "/uploads/...",
      "author_name": "User Name",
      "author_email": "user@example.com",
      "child_count": 5,
      ...
    },
    ...
  ]
}
```
