# sign-in Python implementation
*server-side authentication endpoints for Firefly*

## File Location

`apps/firefly/product/server/imp/py/app.py`

## Dependencies

Already available:
- `db.py`: Database operations (create_user, get_user_by_email, add_device_to_user)
- Email sending function from `features/infrastructure/email/imp/py.md`

New imports needed:
```python
import random
from datetime import datetime, timedelta
```

## Global State

Add to top of app.py (after Flask app creation):

```python
# In-memory storage for verification codes
# Structure: {email: {"code": "1234", "timestamp": datetime}}
pending_codes = {}
```

## Helper Functions

### generate_verification_code()

```python
def generate_verification_code():
    """Generate a random 4-digit verification code"""
    return f"{random.randint(0, 9999):04d}"
```

### clean_expired_codes()

```python
def clean_expired_codes():
    """Remove verification codes older than 10 minutes"""
    now = datetime.now()
    expired_emails = []

    for email, data in pending_codes.items():
        if now - data["timestamp"] > timedelta(minutes=10):
            expired_emails.append(email)

    for email in expired_emails:
        del pending_codes[email]
```

### send_verification_email(email, code)

Copy the `send_email` function from `features/infrastructure/email/imp/py.md` and add wrapper:

```python
def send_verification_email(email, code):
    """Send verification code to user's email"""
    subject = "Firefly Verification Code"
    body = f"""Your Firefly verification code is: {code}

This code will expire in 10 minutes.

If you didn't request this code, you can safely ignore this email.
"""
    result = send_email(email, subject, body)
    return result == 'success'
```

## API Endpoints

### POST /api/auth/send-code

Add to app.py:

```python
@app.route('/api/auth/send-code', methods=['POST'])
def send_code():
    """Send verification code to user's email"""
    data = request.get_json()
    email = data.get('email', '').strip().lower()

    if not email:
        return jsonify({
            'status': 'error',
            'message': 'Email is required'
        }), 400

    # Clean expired codes first
    clean_expired_codes()

    # Check if user exists, create if not
    user = db.get_user_by_email(email)
    if not user:
        print(f"Creating new user: {email}")
        user_id = db.create_user(email)
        if not user_id:
            return jsonify({
                'status': 'error',
                'message': 'Failed to create user'
            }), 500

    # Generate and store code
    code = generate_verification_code()
    pending_codes[email] = {
        "code": code,
        "timestamp": datetime.now()
    }

    print(f"Generated code {code} for {email}")

    # Send email
    if send_verification_email(email, code):
        return jsonify({
            'status': 'success',
            'message': 'Verification code sent'
        })
    else:
        # Remove code if email failed
        del pending_codes[email]
        return jsonify({
            'status': 'error',
            'message': 'Failed to send email'
        }), 500
```

### POST /api/auth/verify-code

Add to app.py:

```python
@app.route('/api/auth/verify-code', methods=['POST'])
def verify_code():
    """Verify the code and authenticate user"""
    data = request.get_json()
    email = data.get('email', '').strip().lower()
    code = data.get('code', '').strip()
    device_id = data.get('device_id', '').strip()

    if not email or not code or not device_id:
        return jsonify({
            'status': 'error',
            'message': 'Email, code, and device_id are required'
        }), 400

    # Clean expired codes
    clean_expired_codes()

    # Check if code exists
    if email not in pending_codes:
        return jsonify({
            'status': 'error',
            'message': 'No verification code found. Please request a new code.'
        }), 404

    # Verify code
    stored_data = pending_codes[email]
    if stored_data["code"] != code:
        return jsonify({
            'status': 'error',
            'message': 'Invalid verification code'
        }), 401

    # Code is valid - get user and add device
    user = db.get_user_by_email(email)
    if not user:
        return jsonify({
            'status': 'error',
            'message': 'User not found'
        }), 404

    # Add device to user
    success = db.add_device_to_user(user['id'], device_id)
    if not success:
        print(f"Warning: Failed to add device {device_id} to user {user['id']}")

    # Remove used code
    del pending_codes[email]

    print(f"User {email} authenticated successfully with device {device_id}")

    return jsonify({
        'status': 'success',
        'user_id': user['id'],
        'email': user['email']
    })
```

## Integration Steps

1. **Import email function**: Copy `send_email()` function from `features/infrastructure/email/imp/py.md` into app.py
2. **Add global state**: Add `pending_codes = {}` dictionary at module level
3. **Add helper functions**: Add the three helper functions above
4. **Add endpoints**: Add both POST endpoints to app.py
5. **Import db module**: Ensure `from db import db` is at top of app.py

## Testing

Test with curl:

```bash
# Send code
curl -X POST http://185.96.221.52:8080/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# Verify code (use code from email)
curl -X POST http://185.96.221.52:8080/api/auth/verify-code \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "code": "1234", "device_id": "test-device-uuid"}'
```

Expected responses:
- send-code success: `{"status": "success", "message": "Verification code sent"}`
- verify-code success: `{"status": "success", "user_id": 1, "email": "test@example.com"}`
- verify-code failure: `{"status": "error", "message": "Invalid verification code"}`

## Security Notes

- Codes expire after 10 minutes
- Used codes are immediately deleted
- Email addresses are normalized (trimmed, lowercased)
- Device IDs are tracked for multi-device support
- Rate limiting should be added in production (not implemented yet)
