# reparent-post implementation (Python)

## Database Function (db.py)

Add this function to the Database class in `apps/firefly/product/server/imp/py/db.py`:

```python
def set_post_parent(self, post_id: int, parent_id: Optional[int]) -> bool:
    """
    Set or update the parent of a post.

    Args:
        post_id: ID of the post to update
        parent_id: ID of the new parent post (or None to make it a root post)

    Returns:
        True if successful, False otherwise
    """
    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            # Verify both posts exist if parent_id is provided
            if parent_id is not None:
                cur.execute("SELECT id FROM posts WHERE id = %s", (parent_id,))
                if cur.fetchone() is None:
                    print(f"Parent post {parent_id} does not exist")
                    return False

            cur.execute("SELECT id FROM posts WHERE id = %s", (post_id,))
            if cur.fetchone() is None:
                print(f"Post {post_id} does not exist")
                return False

            # Update the parent_id
            cur.execute(
                "UPDATE posts SET parent_id = %s WHERE id = %s",
                (parent_id, post_id)
            )
            conn.commit()
            return True
    except Exception as e:
        conn.rollback()
        print(f"Error setting post parent: {e}")
        return False
    finally:
        self.return_connection(conn)
```

**Location**: Add after the `get_recent_posts` method, before the global database instance declaration.

## API Endpoint (app.py)

Add this route to `apps/firefly/product/server/imp/py/app.py`:

```python
@app.route('/api/posts/reparent', methods=['POST'])
def reparent_post():
    """Set the parent of a post"""
    try:
        data = request.get_json()
        post_id = data.get('post_id')
        parent_id = data.get('parent_id')

        # Validate input
        if post_id is None:
            return jsonify({
                'status': 'error',
                'message': 'post_id is required'
            }), 400

        # Call database function
        success = db.set_post_parent(post_id, parent_id)

        if success:
            return jsonify({
                'status': 'success',
                'message': f'Post {post_id} reparented successfully'
            })
        else:
            return jsonify({
                'status': 'error',
                'message': 'Failed to reparent post'
            }), 400

    except Exception as e:
        print(f"Error reparenting post: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500
```

**Location**: Add after the `get_post` endpoint, before the `shutdown` endpoint.

## Testing

To test manually from command line:

```bash
# Make post 2 a child of post 1
curl -X POST http://localhost:8080/api/posts/reparent \
  -H "Content-Type: application/json" \
  -d '{"post_id": 2, "parent_id": 1}'

# Make post 3 a child of post 1
curl -X POST http://localhost:8080/api/posts/reparent \
  -H "Content-Type: application/json" \
  -d '{"post_id": 3, "parent_id": 1}'

# Make post 2 a root post again
curl -X POST http://localhost:8080/api/posts/reparent \
  -H "Content-Type: application/json" \
  -d '{"post_id": 2, "parent_id": null}'
```
