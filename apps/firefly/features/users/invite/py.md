# invite - Python Implementation
*Flask server implementation for invite feature*

## Database Migration

Add to database setup:

```python
def create_pending_invites_table():
    """Create pending_invites table"""
    db.execute('''
        CREATE TABLE IF NOT EXISTS pending_invites (
            id SERIAL PRIMARY KEY,
            inviter_user_id INTEGER REFERENCES users(id),
            invitee_email VARCHAR(255) NOT NULL,
            invite_date TIMESTAMP DEFAULT NOW()
        )
    ''')
    db.commit()
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

### POST /api/invite

```python
@app.route('/api/invite', methods=['POST'])
def create_invite():
    """Create a new invite or check if user already exists"""
    data = request.get_json()
    invitee_email = data.get('email', '').lower().strip()

    # Get current user ID from session/auth
    inviter_user_id = get_current_user_id()

    if not invitee_email:
        return jsonify({'status': 'error', 'message': 'Email required'}), 400

    # Check if user already exists
    existing_user = db.query_one('SELECT id FROM users WHERE email = %s', (invitee_email,))

    if existing_user:
        return jsonify({
            'status': 'already_exists',
            'user_id': existing_user['id'],
            'testflight_link': get_testflight_link()
        })

    # Create pending invite
    db.execute(
        'INSERT INTO pending_invites (inviter_user_id, invitee_email) VALUES (%s, %s)',
        (inviter_user_id, invitee_email)
    )
    db.commit()

    logger.info(f"[Invite] User {inviter_user_id} invited {invitee_email}")

    return jsonify({
        'status': 'invite_created',
        'testflight_link': get_testflight_link()
    })
```

### GET /api/testflight-link

```python
@app.route('/api/testflight-link', methods=['GET'])
def get_testflight_link_endpoint():
    """Get the TestFlight public link"""
    return jsonify({
        'link': get_testflight_link()
    })
```

## Helper Function

```python
def get_current_user_id():
    """Get current user ID from storage/session"""
    # This should use the existing auth mechanism
    # For now, get from device_id in request
    data = request.get_json() or {}
    device_id = data.get('device_id') or request.headers.get('X-Device-ID')

    if not device_id:
        return None

    user = db.query_one(
        'SELECT id FROM users WHERE device_ids ? %s',
        (device_id,)
    )

    return user['id'] if user else None
```

## Database Migration Script

Add to your migration or setup script:

```python
# In app.py or migration script
if __name__ == '__main__':
    # Existing migrations...

    # Add pending_invites table
    create_pending_invites_table()
```
