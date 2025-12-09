# notifications - Python/Server implementation
*APNs push notification sending via PyAPNs2*

## Prerequisites

1. **Install PyAPNs2**:
   ```bash
   pip3 install apns2
   ```

2. **Create APNs Key in Apple Developer Portal**:
   - Go to https://developer.apple.com/account/resources/authkeys/list
   - Click "+" to create new key
   - Check "Apple Push Notifications service (APNs)"
   - Download the `.p8` file (only downloadable once!)
   - Note the Key ID (10 characters)
   - Note your Team ID (from Membership page)

3. **Add to server .env**:
   ```
   APNS_KEY_ID=ABC123DEFG
   APNS_TEAM_ID=XYZ789
   APNS_KEY_PATH=/path/to/AuthKey_ABC123DEFG.p8
   APNS_BUNDLE_ID=com.miso.noobtest
   APNS_USE_SANDBOX=true
   ```

---

## Database Schema Changes

Add `apns_device_token` column to users table:

```sql
ALTER TABLE users ADD COLUMN apns_device_token VARCHAR(255);
```

---

## APNs Client Module

Create `apns_client.py`:

```python
"""
APNs (Apple Push Notification service) client for sending push notifications.
Uses PyAPNs2 with JWT token-based authentication.
"""

import os
from apns2.client import APNsClient, NotificationPriority
from apns2.payload import Payload
from apns2.credentials import TokenCredentials

class PushNotificationService:
    """Service for sending push notifications via APNs"""

    def __init__(self):
        self.client = None
        self.bundle_id = os.getenv('APNS_BUNDLE_ID', 'com.miso.noobtest')
        self._initialize_client()

    def _initialize_client(self):
        """Initialize APNs client with JWT credentials"""
        key_id = os.getenv('APNS_KEY_ID')
        team_id = os.getenv('APNS_TEAM_ID')
        key_path = os.getenv('APNS_KEY_PATH')
        use_sandbox = os.getenv('APNS_USE_SANDBOX', 'true').lower() == 'true'

        if not all([key_id, team_id, key_path]):
            print("[APNS] Missing configuration, push notifications disabled")
            print(f"[APNS] KEY_ID={key_id}, TEAM_ID={team_id}, KEY_PATH={key_path}")
            return

        if not os.path.exists(key_path):
            print(f"[APNS] Key file not found: {key_path}")
            return

        try:
            credentials = TokenCredentials(
                auth_key_path=key_path,
                auth_key_id=key_id,
                team_id=team_id
            )
            self.client = APNsClient(
                credentials=credentials,
                use_sandbox=use_sandbox
            )
            env = "sandbox" if use_sandbox else "production"
            print(f"[APNS] Client initialized ({env})")
        except Exception as e:
            print(f"[APNS] Failed to initialize client: {e}")

    def send_notification(self, device_token: str, title: str, body: str, badge: int = 1):
        """
        Send a push notification to a device.

        Args:
            device_token: APNs device token (hex string)
            title: Notification title
            body: Notification body text
            badge: App icon badge number (default 1)
        """
        if not self.client:
            print("[APNS] Client not initialized, skipping notification")
            return False

        if not device_token:
            print("[APNS] No device token provided")
            return False

        try:
            payload = Payload(
                alert={"title": title, "body": body},
                badge=badge,
                sound="default"
            )

            self.client.send_notification(
                token_hex=device_token,
                notification=payload,
                topic=self.bundle_id,
                priority=NotificationPriority.Immediate
            )
            print(f"[APNS] Sent: '{title}' to {device_token[:8]}...")
            return True

        except Exception as e:
            print(f"[APNS] Failed to send notification: {e}")
            return False

    def send_to_user(self, db, user_id: int, title: str, body: str):
        """
        Send notification to a user by their user ID.

        Args:
            db: Database instance
            user_id: User's database ID
            title: Notification title
            body: Notification body text
        """
        user = db.get_user_by_id(user_id)
        if not user:
            print(f"[APNS] User {user_id} not found")
            return False

        token = user.get('apns_device_token')
        if not token:
            print(f"[APNS] User {user_id} has no device token")
            return False

        return self.send_notification(token, title, body)


# Global instance
push_service = PushNotificationService()
```

---

## Database Methods

Add to `db.py`:

```python
def update_user_apns_token(self, user_id: int, apns_token: str) -> bool:
    """Update a user's APNs device token"""
    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE users SET apns_device_token = %s WHERE id = %s",
                (apns_token, user_id)
            )
            conn.commit()
            return cur.rowcount > 0
    except Exception as e:
        conn.rollback()
        print(f"Error updating APNs token: {e}")
        return False
    finally:
        self.return_connection(conn)

def get_all_users_with_tokens(self) -> list:
    """Get all users who have APNs tokens registered"""
    conn = self.get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT id, name, email, apns_device_token FROM users WHERE apns_device_token IS NOT NULL"
            )
            return cur.fetchall()
    except Exception as e:
        print(f"Error getting users with tokens: {e}")
        return []
    finally:
        self.return_connection(conn)

def get_queries_matching_post(self, post_embedding: list) -> list:
    """Find all query posts that match a given post embedding"""
    conn = self.get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Find queries with cosine similarity > threshold
            cur.execute("""
                SELECT p.id, p.title, p.user_id, u.name as user_name,
                       1 - (p.embedding <=> %s::vector) as similarity
                FROM posts p
                JOIN users u ON p.user_id = u.id
                WHERE p.template_name = 'query'
                AND p.embedding IS NOT NULL
                AND 1 - (p.embedding <=> %s::vector) > 0.3
            """, (post_embedding, post_embedding))
            return cur.fetchall()
    except Exception as e:
        print(f"Error finding matching queries: {e}")
        return []
    finally:
        self.return_connection(conn)
```

---

## API Endpoints

Add to `app.py`:

```python
from apns_client import push_service

@app.route('/api/notifications/register-device', methods=['POST'])
def register_device_token():
    """Register an APNs device token for push notifications"""
    data = request.get_json()
    device_id = data.get('device_id')
    apns_token = data.get('apns_token')

    if not device_id or not apns_token:
        return jsonify({'status': 'error', 'message': 'device_id and apns_token required'}), 400

    # Find user by device_id
    user = db.get_user_by_device_id(device_id)
    if not user:
        return jsonify({'status': 'error', 'message': 'User not found'}), 404

    # Update their APNs token
    success = db.update_user_apns_token(user['id'], apns_token)
    if success:
        print(f"[PUSH] Registered token for user {user['id']} ({user.get('name', 'unknown')})")
        return jsonify({'status': 'ok'})
    else:
        return jsonify({'status': 'error', 'message': 'Failed to update token'}), 500
```

---

## Notification Triggers

Add helper functions to `app.py`:

```python
def notify_new_post(post, author):
    """Send push notifications for a new post"""
    if post.get('template_name') != 'post':
        return  # Only notify for regular posts

    author_id = author['id']
    author_name = author.get('name', 'Someone')

    # Get all users with tokens except author
    all_users = db.get_all_users_with_tokens()
    recipients = [u for u in all_users if u['id'] != author_id]

    if not recipients:
        return

    # Check for query matches
    post_embedding = post.get('embedding')
    matching_queries = []
    if post_embedding:
        matching_queries = db.get_queries_matching_post(post_embedding)

    # Build map of user_id -> query title for matches
    user_query_matches = {}
    for q in matching_queries:
        if q['user_id'] not in user_query_matches:
            user_query_matches[q['user_id']] = q['title']

    # Send notifications
    for user in recipients:
        user_id = user['id']
        if user_id in user_query_matches:
            # Consolidated notification mentioning query match
            query_title = user_query_matches[user_id]
            push_service.send_notification(
                user['apns_device_token'],
                title="New match",
                body=f"'{query_title}' matched a post from {author_name}"
            )
        else:
            # Standard new post notification
            push_service.send_notification(
                user['apns_device_token'],
                title="New post",
                body=f"New post from {author_name}"
            )


def notify_new_user(new_user):
    """Send push notifications when a new user completes their profile"""
    new_user_id = new_user['id']
    new_user_name = new_user.get('name', 'Someone')

    # Get all users with tokens except the new user
    all_users = db.get_all_users_with_tokens()
    recipients = [u for u in all_users if u['id'] != new_user_id]

    for user in recipients:
        push_service.send_notification(
            user['apns_device_token'],
            title="New member",
            body=f"{new_user_name} just joined"
        )
```

---

## Integration Points

Call notification functions from existing endpoints:

### In create_post endpoint:
```python
@app.route('/api/posts', methods=['POST'])
def create_post():
    # ... existing post creation code ...

    # After successful creation:
    if new_post and new_post.get('template_name') == 'post':
        notify_new_post(new_post, author)

    return jsonify({'status': 'ok', 'post_id': post_id})
```

### In profile completion endpoint:
```python
@app.route('/api/users/profile/create', methods=['POST'])
def create_user_profile():
    # ... existing profile creation code ...

    # After marking profile complete:
    user = db.get_user_by_id(user_id)
    notify_new_user(user)

    return jsonify({'status': 'ok'})
```

---

## Patching Instructions

### 1. Add database column
```bash
ssh microserver@185.96.221.52
cd ~/firefly-server
PGPASSWORD=firefly_pass psql -h localhost -U firefly_user -d firefly -c \
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS apns_device_token VARCHAR(255);"
```

### 2. Install PyAPNs2
```bash
pip3 install apns2
# Add to requirements.txt: apns2
```

### 3. Upload APNs key
- Upload .p8 file to server: `scp AuthKey_XXX.p8 microserver@185.96.221.52:~/firefly-server/`
- Add environment variables to .env

### 4. Create apns_client.py
Create new file with PushNotificationService class.

### 5. Update db.py
Add `update_user_apns_token`, `get_all_users_with_tokens`, `get_queries_matching_post` methods.

### 6. Update app.py
- Import `push_service` from apns_client
- Add `/api/notifications/register-device` endpoint
- Add `notify_new_post` and `notify_new_user` helper functions
- Call notification functions from post creation and profile completion endpoints

### 7. Deploy
```bash
./remote-shutdown.sh
scp *.py *.txt *.sh *.p8 microserver@185.96.221.52:~/firefly-server/
ssh microserver@185.96.221.52 "cd ~/firefly-server && ./start.sh"
```

---

## Testing

1. Create test endpoint to send manual notification:
```python
@app.route('/api/test/push', methods=['POST'])
def test_push():
    data = request.get_json()
    device_token = data.get('token')
    push_service.send_notification(device_token, "Test", "Hello from server!")
    return jsonify({'status': 'ok'})
```

2. Get device token from iOS logs after registration
3. Call test endpoint with that token
4. Verify notification appears on device
