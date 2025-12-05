# invite - Python Implementation
*Flask server implementation for invite feature*

## Database Migration

Add `num_invites` column to users table:

```sql
ALTER TABLE users ADD COLUMN num_invites INTEGER NOT NULL DEFAULT 0;
-- Grant specific users invites as needed:
UPDATE users SET num_invites = 128 WHERE name = 'asnaroo';
```

## Configuration

Add TestFlight link to config or environment:

```python
# In config.py or as environment variable
TESTFLIGHT_PUBLIC_LINK = "https://testflight.apple.com/join/XXXXX"

def get_testflight_link():
    """Get TestFlight public link from config"""
    return os.getenv('TESTFLIGHT_PUBLIC_LINK', TESTFLIGHT_PUBLIC_LINK)
```

## API Endpoints

### GET /api/user/invites

```python
@app.route('/api/user/invites', methods=['GET'])
def get_user_invites():
    """Get the number of invites remaining for the current user"""
    device_id = request.args.get('device_id', '').strip()

    if not device_id:
        return jsonify({'status': 'error', 'message': 'Device ID required'}), 400

    user = db.get_user_by_device_id(device_id)
    if not user:
        return jsonify({'status': 'error', 'message': 'Not authenticated'}), 401

    # Get num_invites from database
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT num_invites FROM users WHERE id = %s", (user['id'],))
            row = cur.fetchone()
            num_invites = row[0] if row else 0
    finally:
        db.return_connection(conn)

    return jsonify({
        'status': 'success',
        'num_invites': num_invites
    })
```

### POST /api/invite

```python
@app.route('/api/invite', methods=['POST'])
def create_invite():
    """Create a new invite for a user"""
    data = request.get_json()
    device_id = data.get('device_id', '').strip()
    invitee_name = data.get('name', '').strip()
    invitee_email = data.get('email', '').strip().lower()

    # Get inviter
    inviter = db.get_user_by_device_id(device_id)
    if not inviter:
        return jsonify({'status': 'error', 'message': 'Not authenticated'}), 401

    # Check if inviter has invites remaining
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT num_invites FROM users WHERE id = %s", (inviter['id'],))
            row = cur.fetchone()
            num_invites = row[0] if row else 0
    finally:
        db.return_connection(conn)

    if num_invites <= 0:
        return jsonify({'status': 'error', 'message': 'No invites remaining'}), 403

    # Check if user already exists
    existing_user = db.get_user_by_email(invitee_email)
    testflight_url = config.get_config_value('TESTFLIGHT_URL')

    if existing_user:
        return jsonify({
            'status': 'already_exists',
            'user_name': existing_user.get('name', ''),
            'testflight_link': testflight_url
        })

    # Create new user from invite
    new_user_id = db.create_user_from_invite(invitee_email, invitee_name, inviter['id'])

    # Decrement inviter's invite count
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE users SET num_invites = num_invites - 1 WHERE id = %s AND num_invites > 0", (inviter['id'],))
            conn.commit()
    finally:
        db.return_connection(conn)

    invite_message = f"Hi {invitee_name}! I'd like you to try microclub.\nDownload it here: {testflight_url}"

    return jsonify({
        'status': 'invite_created',
        'testflight_link': testflight_url,
        'invite_message': invite_message
    })
```

