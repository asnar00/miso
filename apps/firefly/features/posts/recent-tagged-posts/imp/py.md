# Python Implementation: Recent Tagged Posts

## Overview

Flask server endpoint for unified recent-tagged-posts feature.

## Endpoint

```python
@app.route('/api/posts/recent-tagged', methods=['GET'])
@require_auth
def get_recent_tagged_posts():
    """
    Fetch recent posts filtered by template tags and user.

    Query parameters:
    - tags: Comma-separated template names (optional, omit for all posts)
    - by_user: "any" or "current"
    - limit: Max results (default: 50)

    Returns: Array of post objects with childCount
    """
    try:
        # Get parameters
        tags_param = request.args.get('tags', '')  # Empty string if not provided
        by_user = request.args.get('by_user', 'any')
        limit = int(request.args.get('limit', 50))

        # Parse tags
        tags = [tag.strip() for tag in tags_param.split(',') if tag.strip()] if tags_param else []

        # Get current user
        current_user_id = session.get('user_id')

        conn = get_db()
        cursor = conn.cursor()

        # Build query
        query = """
            SELECT
                p.id, p.title, p.summary, p.body, p.image_url,
                p.parent_id, p.author_id, p.created_at, p.template_name,
                u.name as author_name,
                (SELECT COUNT(*) FROM posts WHERE parent_id = p.id) as childCount
            FROM posts p
            JOIN users u ON p.author_id = u.id
        """

        conditions = []
        params = []

        # Filter by tags if provided
        if tags:
            placeholders = ','.join(['?' for _ in tags])
            conditions.append(f"p.template_name IN ({placeholders})")
            params.extend(tags)

        # Filter by user if "current"
        if by_user == "current":
            conditions.append("p.author_id = ?")
            params.append(current_user_id)

        # Add WHERE clause if conditions exist
        if conditions:
            query += " WHERE " + " AND ".join(conditions)

        # Sort order
        if "profile" in tags:
            # For profiles, sort by user's last activity
            query += """
                ORDER BY (
                    SELECT MAX(created_at)
                    FROM posts
                    WHERE author_id = p.author_id
                ) DESC
            """
        else:
            # For other posts, sort by creation date
            query += " ORDER BY p.created_at DESC"

        # Limit results
        query += " LIMIT ?"
        params.append(limit)

        cursor.execute(query, params)
        rows = cursor.fetchall()

        posts = []
        for row in rows:
            post = {
                'id': row[0],
                'title': row[1],
                'summary': row[2],
                'body': row[3],
                'imageUrl': row[4],
                'parentId': row[5],
                'authorId': row[6],
                'createdAt': row[7],
                'templateName': row[8],
                'authorName': row[9],
                'childCount': row[10]
            }
            posts.append(post)

        conn.close()
        return jsonify(posts)

    except Exception as e:
        print(f"Error fetching recent tagged posts: {e}")
        return jsonify({'error': str(e)}), 500
```

## Database Schema Notes

Required tables and columns:
- `posts`: id, title, summary, body, image_url, parent_id, author_id, created_at, template_name
- `users`: id, name, last_activity

The template_name column should exist in the posts table (added in templates feature).

## Migration from Old Endpoints

The old endpoints can remain for backward compatibility but should be deprecated:

```python
# OLD - keep for backward compatibility
@app.route('/api/posts/recent', methods=['GET'])
@require_auth
def get_recent_posts():
    # Redirect to new endpoint
    return get_recent_tagged_posts_internal(tags=['post'], by_user='any')

@app.route('/api/users/recent', methods=['GET'])
@require_auth
def get_recent_users():
    # Redirect to new endpoint
    return get_recent_tagged_posts_internal(tags=['profile'], by_user='any')
```

## Template Information Endpoint

**CRITICAL:** This endpoint must properly manage database connections to avoid pool exhaustion.

```python
@app.route('/api/templates/<template_name>', methods=['GET'])
def get_template(template_name):
    """Get template information including plural name"""
    conn = db.get_connection()  # Acquire connection OUTSIDE try block
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT name, placeholder_title, placeholder_summary, placeholder_body, plural_name
                FROM templates
                WHERE name = %s
            """, (template_name,))

            row = cur.fetchone()
            if not row:
                return jsonify({
                    'status': 'error',
                    'message': 'Template not found'
                }), 404

            template = {
                'name': row[0],
                'placeholder_title': row[1],
                'placeholder_summary': row[2],
                'placeholder_body': row[3],
                'plural_name': row[4]
            }

            return jsonify({
                'status': 'success',
                'template': template
            })

    except Exception as e:
        print(f"Error fetching template: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500
    finally:
        db.return_connection(conn)  # CRITICAL: Always return connection to pool
```

### Connection Pool Management

**The Bug:** The original implementation had the connection acquired inside the try block and no finally block. This caused connection pool exhaustion because connections were never returned to the pool, especially when early returns occurred (like the 404 case).

**Symptoms of connection leak:**
- Server crashes after ~10-20 requests to `/api/templates/:template_name`
- Error: `psycopg2.pool.PoolError: connection pool exhausted`
- All endpoints start returning 500 errors
- Server becomes completely unresponsive

**The Fix:** Move connection acquisition outside try block, add finally block that ALWAYS returns the connection.

**Pattern to follow for ALL endpoints using db.get_connection():**
```python
conn = db.get_connection()  # Outside try
try:
    # Use connection
    result = do_work(conn)
    return jsonify(result)
except Exception as e:
    return jsonify({'error': str(e)}), 500
finally:
    db.return_connection(conn)  # ALWAYS execute
```

## Target File

**apps/firefly/product/server/imp/py/app.py**

Add the new endpoint after the existing posts endpoints (around line 400).

## Complete Implementation

```python
@app.route('/api/posts/recent-tagged', methods=['GET'])
@require_auth
def get_recent_tagged_posts():
    """Fetch recent posts filtered by template tags and user."""
    try:
        tags_param = request.args.get('tags', '')
        by_user = request.args.get('by_user', 'any')
        limit = int(request.args.get('limit', 50))

        tags = [tag.strip() for tag in tags_param.split(',') if tag.strip()] if tags_param else []

        current_user_id = session.get('user_id')

        conn = get_db()
        cursor = conn.cursor()

        query = """
            SELECT
                p.id, p.title, p.summary, p.body, p.image_url,
                p.parent_id, p.author_id, p.created_at, p.template_name,
                u.name as author_name,
                (SELECT COUNT(*) FROM posts WHERE parent_id = p.id) as childCount
            FROM posts p
            JOIN users u ON p.author_id = u.id
        """

        conditions = []
        params = []

        if tags:
            placeholders = ','.join(['?' for _ in tags])
            conditions.append(f"p.template_name IN ({placeholders})")
            params.extend(tags)

        if by_user == "current":
            conditions.append("p.author_id = ?")
            params.append(current_user_id)

        if conditions:
            query += " WHERE " + " AND ".join(conditions)

        if "profile" in tags:
            query += """
                ORDER BY (
                    SELECT MAX(created_at)
                    FROM posts
                    WHERE author_id = p.author_id
                ) DESC
            """
        else:
            query += " ORDER BY p.created_at DESC"

        query += " LIMIT ?"
        params.append(limit)

        cursor.execute(query, params)
        rows = cursor.fetchall()

        posts = []
        for row in rows:
            post = {
                'id': row[0],
                'title': row[1],
                'summary': row[2],
                'body': row[3],
                'imageUrl': row[4],
                'parentId': row[5],
                'authorId': row[6],
                'createdAt': row[7],
                'templateName': row[8],
                'authorName': row[9],
                'childCount': row[10]
            }
            posts.append(post)

        conn.close()
        return jsonify(posts)

    except Exception as e:
        print(f"Error fetching recent tagged posts: {e}")
        return jsonify({'error': str(e)}), 500
```
