# create-post implementation (Python)

## Database Function (db.py)

Already implemented at `apps/firefly/product/server/imp/py/db.py:148`

```python
def create_post(
    self,
    user_id: int,
    title: str,
    summary: str,
    body: str,
    timezone: str,
    parent_id: Optional[int] = None,
    image_url: Optional[str] = None,
    location_tag: Optional[str] = None,
    ai_generated: bool = False,
    embedding: Optional[List[float]] = None
) -> Optional[int]:
    """
    Create a new post.

    Args:
        user_id: ID of the user creating the post
        title: Post title
        summary: One-line summary
        body: Post body text
        timezone: User's timezone
        parent_id: ID of parent post (if this is a child post)
        image_url: URL to post image
        location_tag: Optional location tag
        ai_generated: Whether this post was AI-generated
        embedding: Vector embedding for semantic search

    Returns:
        Post ID if successful, None otherwise
    """
    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO posts
                (user_id, parent_id, title, summary, body, image_url, timezone, location_tag, ai_generated, embedding)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
                """,
                (user_id, parent_id, title, summary, body, image_url, timezone, location_tag, ai_generated, embedding)
            )
            post_id = cur.fetchone()[0]
            conn.commit()
            return post_id
    except Exception as e:
        conn.rollback()
        print(f"Error creating post: {e}")
        return None
    finally:
        self.return_connection(conn)
```

**Location**: Database class in `apps/firefly/product/server/imp/py/db.py`, line 148

## API Endpoint (app.py)

Already implemented at `apps/firefly/product/server/imp/py/app.py:261`

```python
@app.route('/api/posts/create', methods=['POST'])
def create_post():
    """Create a new post with optional image upload"""
    try:
        # Get form data
        email = request.form.get('email', '').strip().lower()
        title = request.form.get('title', '').strip()
        summary = request.form.get('summary', '').strip()
        body = request.form.get('body', '').strip()
        timezone = request.form.get('timezone', 'UTC')
        location_tag = request.form.get('location_tag', '').strip() or None
        ai_generated = request.form.get('ai_generated', 'false').lower() == 'true'

        # Get optional parent_id
        parent_id = None
        parent_id_str = request.form.get('parent_id', '').strip()
        if parent_id_str:
            try:
                parent_id = int(parent_id_str)
            except ValueError:
                return jsonify({
                    'status': 'error',
                    'message': 'parent_id must be a valid integer'
                }), 400

        # Validate required fields
        if not email or not title or not summary or not body:
            return jsonify({
                'status': 'error',
                'message': 'email, title, summary, and body are required'
            }), 400

        # Look up user by email
        user = db.get_user_by_email(email)
        if not user:
            return jsonify({
                'status': 'error',
                'message': f'User not found: {email}'
            }), 404

        user_id = user['id']

        # Handle image upload if present
        image_url = None
        if 'image' in request.files:
            file = request.files['image']
            if file and file.filename and allowed_file(file.filename):
                # Generate unique filename
                ext = file.filename.rsplit('.', 1)[1].lower()
                filename = f"{uuid.uuid4().hex}.{ext}"
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                file.save(filepath)
                image_url = f"/uploads/{filename}"
                print(f"Uploaded image: {filename}")

        # Create post in database
        post_id = db.create_post(
            user_id=user_id,
            title=title,
            summary=summary,
            body=body,
            timezone=timezone,
            parent_id=parent_id,
            image_url=image_url,
            location_tag=location_tag,
            ai_generated=ai_generated
        )

        if not post_id:
            return jsonify({
                'status': 'error',
                'message': 'Failed to create post'
            }), 500

        print(f"Created post {post_id} by user {email} (ID: {user_id})")

        # Fetch the created post to return it
        post = db.get_post_by_id(post_id)
        if not post:
            return jsonify({
                'status': 'error',
                'message': 'Post created but failed to retrieve'
            }), 500

        return jsonify({
            'status': 'success',
            'post': post
        })

    except Exception as e:
        print(f"Error creating post: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500
```

**Location**: Flask app in `apps/firefly/product/server/imp/py/app.py`, line 261

## Configuration

**Allowed file extensions**: png, jpg, jpeg, gif, webp
**Max file size**: 16MB
**Upload folder**: `uploads/` (created automatically)

Helper function at app.py:252:
```python
def allowed_file(filename):
    """Check if uploaded file has an allowed extension"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
```

## Testing

Using curl with multipart form data:

```bash
# Create post with image
curl -X POST http://185.96.221.52:8080/api/posts/create \
  -F "email=user@example.com" \
  -F "title=My Post Title" \
  -F "summary=A brief one-line summary" \
  -F "body=The full post content goes here..." \
  -F "timezone=Europe/Madrid" \
  -F "location_tag=Barcelona, Spain" \
  -F "image=@/path/to/image.jpg"

# Create post without image
curl -X POST http://185.96.221.52:8080/api/posts/create \
  -F "email=user@example.com" \
  -F "title=Text Only Post" \
  -F "summary=No image this time" \
  -F "body=Just some text content"

# Create child post (with parent_id)
curl -X POST http://185.96.221.52:8080/api/posts/create \
  -F "email=user@example.com" \
  -F "title=Child Post" \
  -F "summary=This is a child of another post" \
  -F "body=This post is part of a tree structure" \
  -F "parent_id=6"
```

**Response**:
```json
{
  "status": "success",
  "post": {
    "id": 123,
    "user_id": 7,
    "parent_id": null,
    "title": "My Post Title",
    "summary": "A brief one-line summary",
    "body": "The full post content goes here...",
    "image_url": "/uploads/abc123def456.jpg",
    "created_at": "Wed, 16 Oct 2025 10:30:00 GMT",
    "timezone": "Europe/Madrid",
    "location_tag": "Barcelona, Spain",
    "ai_generated": false,
    "author_name": "user@example.com"
  }
}
```
