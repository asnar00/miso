# Profile Feature - Python Server Implementation

## Database Functions

**File:** `apps/firefly/product/server/imp/py/db.py`

Add these methods to the `Database` class (after the post operations):

```python
def get_user_profile(self, user_id: int) -> Optional[Dict[str, Any]]:
    """
    Get a user's profile post (post with parent_id = -1).

    Args:
        user_id: The user's ID

    Returns:
        Profile post dict if found, None otherwise
    """
    conn = self.get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT
                    p.id, p.user_id, p.parent_id, p.title, p.summary, p.body,
                    p.image_url, p.created_at, p.timezone, p.location_tag, p.ai_generated,
                    u.email as author_name,
                    0 as child_count
                FROM posts p
                LEFT JOIN users u ON p.user_id = u.id
                WHERE p.user_id = %s AND p.parent_id = -1
                LIMIT 1
            """, (user_id,))
            result = cur.fetchone()

            if result:
                return dict(result)
            return None
    except Exception as e:
        print(f"Error getting user profile: {e}")
        return None
    finally:
        self.return_connection(conn)

def create_profile_post(
    self,
    user_id: int,
    title: str,
    summary: str,
    body: str,
    timezone: str = 'UTC',
    image_url: Optional[str] = None
) -> Optional[int]:
    """
    Create a profile post for a user (with parent_id = -1).

    Args:
        user_id: User creating the profile
        title: User's name
        summary: User's profession/mission
        body: About text
        timezone: User's timezone
        image_url: Optional profile photo URL

    Returns:
        Post ID if successful, None otherwise
    """
    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO posts (user_id, parent_id, title, summary, body, timezone, image_url, ai_generated)
                VALUES (%s, -1, %s, %s, %s, %s, %s, false)
                RETURNING id
            """, (user_id, title, summary, body, timezone, image_url))
            post_id = cur.fetchone()[0]
            conn.commit()
            print(f"Created profile post {post_id} for user {user_id}")
            return post_id
    except Exception as e:
        conn.rollback()
        print(f"Error creating profile post: {e}")
        return None
    finally:
        self.return_connection(conn)

def update_post(
    self,
    post_id: int SOURCE,
    title: Optional[str] = None,
    summary: Optional[str] = None,
    body: Optional[str] = None,
    image_url: Optional[str] = None
) -> bool:
    """
    Update an existing post.

    Args:
        post_id: ID of post to update
        title: New title (optional)
        summary: New summary (optional)
        body: New body (optional)
        image_url: New image URL (optional)

    Returns:
        True if successful, False otherwise
    """
    conn = self.get_connection()
    try:
        # Build dynamic update query
        updates = []
        params = []

        if title is not None:
            updates.append("title = %s")
            params.append(title)

        if summary is not None:
            updates.append("summary = %s")
            params.append(summary)

        if body is not None:
            updates.append("body = %s")
            params.append(body)

        if image_url is not None:
            updates.append("image_url = %s")
            params.append(image_url)

        if not updates:
            print("No fields to update")
            return False

        params.append(post_id)
        query = f"UPDATE posts SET {', '.join(updates)} WHERE id = %s"

        with conn.cursor() as cur:
            cur.execute(query, params)
            conn.commit()
            print(f"Updated post {post_id}")
            return True
    except Exception as e:
        conn.rollback()
        print(f"Error updating post: {e}")
        return False
    finally:
        self.return_connection(conn)
```

## API Endpoints

**File:** `apps/firefly/product/server/imp/py/app.py`

Add these endpoints (after the existing post endpoints, around line 450):

```python
@app.route('/api/users/<int:user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    """Get a user's profile post"""
    try:
        profile = db.get_user_profile(user_id)

        return jsonify({
            'status': 'success',
            'profile': profile
        })
    except Exception as e:
        print(f"Error getting user profile: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/profile/create', methods=['POST'])
def create_profile():
    """Create a new profile post"""
    try:
        # Get form data
        email = request.form.get('email', '').strip().lower()
        title = request.form.get('title', '').strip()
        summary = request.form.get('summary', '').strip()
        body = request.form.get('body', '').strip()
        timezone = request.form.get('timezone', 'UTC')

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

        # Check if profile already exists
        existing_profile = db.get_user_profile(user_id)
        if existing_profile:
            return jsonify({
                'status': 'error',
                'message': 'Profile already exists. Use update endpoint.'
            }), 400

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
                print(f"Uploaded profile image: {filename}")

        # Create profile post
        post_id = db.create_profile_post(
            user_id=user_id,
            title=title,
            summary=summary,
            body=body,
            timezone=timezone,
            image_url=image_url
        )

        if not post_id:
            return jsonify({
                'status': 'error',
                'message': 'Failed to create profile'
            }), 500

        print(f"Created profile {post_id} for user {email} (ID: {user_id})")

        # Fetch the created profile to return it
        profile = db.get_post_by_id(post_id)
        if not profile:
            return jsonify({
                'status': 'error',
                'message': 'Profile created but failed to retrieve'
            }), 500

        return jsonify({
            'status': 'success',
            'profile': profile
        })

    except Exception as e:
        print(f"Error creating profile: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/profile/update', methods=['POST'])
def update_profile():
    """Update an existing profile post"""
    try:
        # Get form data
        post_id_str = request.form.get('post_id', '').strip()
        email = request.form.get('email', '').strip().lower()
        title = request.form.get('title', '').strip()
        summary = request.form.get('summary', '').strip()
        body = request.form.get('body', '').strip()

        # Validate required fields
        if not post_id_str or not email:
            return jsonify({
                'status': 'error',
                'message': 'post_id and email are required'
            }), 400

        try:
            post_id = int(post_id_str)
        except ValueError:
            return jsonify({
                'status': 'error',
                'message': 'post_id must be a valid integer'
            }), 400

        # Look up user by email
        user = db.get_user_by_email(email)
        if not user:
            return jsonify({
                'status': 'error',
                'message': f'User not found: {email}'
            }), 404

        user_id = user['id']

        # Verify the post exists and belongs to the user
        post = db.get_post_by_id(post_id)
        if not post:
            return jsonify({
                'status': 'error',
                'message': 'Profile not found'
            }), 404

        if post['user_id'] != user_id:
            return jsonify({
                'status': 'error',
                'message': 'Unauthorized: Profile belongs to different user'
            }), 403

        if post['parent_id'] != -1:
            return jsonify({
                'status': 'error',
                'message': 'Post is not a profile post'
            }), 400

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
                print(f"Uploaded new profile image: {filename}")

        # Update the profile post
        success = db.update_post(
            post_id=post_id,
            title=title if title else None,
            summary=summary if summary else None,
            body=body if body else None,
            image_url=image_url
        )

        if not success:
            return jsonify({
                'status': 'error',
                'message': 'Failed to update profile'
            }), 500

        print(f"Updated profile {post_id} for user {email} (ID: {user_id})")

        # Fetch the updated profile to return it
        profile = db.get_post_by_id(post_id)
        if not profile:
            return jsonify({
                'status': 'error',
                'message': 'Profile updated but failed to retrieve'
            }), 500

        return jsonify({
            'status': 'success',
            'profile': profile
        })

    except Exception as e:
        print(f"Error updating profile: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500
```

## Patching Instructions

1. **Add database methods to db.py:**
   - Add `get_user_profile()` method around line 250
   - Add `create_profile_post()` method around line 275
   - Add `update_post()` method around line 300

2. **Add API endpoints to app.py:**
   - Add `get_user_profile()` endpoint around line 450
   - Add `create_profile()` endpoint around line 475
   - Add `update_profile()` endpoint around line 530

3. **Deploy to server:**
   - Use the py-deploy-remote skill to deploy changes to the remote server
