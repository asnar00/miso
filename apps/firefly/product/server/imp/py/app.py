from flask import Flask, render_template_string, jsonify, request, send_from_directory
import os
import signal
import random
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from werkzeug.utils import secure_filename
import uuid
from db import db

app = Flask(__name__)

# Configure upload folder
UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Create uploads directory if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# In-memory storage for verification codes
# Structure: {email: {"code": "1234", "timestamp": datetime}}
pending_codes = {}

# HTML template with the noob logo
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Firefly Server</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background-color: #40E0D0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .logo {
            font-size: 120px;
            color: black;
            text-align: center;
        }
        .status {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: rgba(0,0,0,0.1);
            padding: 10px 20px;
            border-radius: 5px;
            font-size: 14px;
            color: black;
        }
    </style>
</head>
<body>
    <div class="logo">ᕦ(ツ)ᕤ</div>
    <div class="status">Firefly Server Running</div>
</body>
</html>
'''

# Email sending function
def send_email(destination, subject, body):
    """Send an email from admin@microclub.org"""
    sender_email = "admin@microclub.org"
    sender_name = "microclub"
    sender_password = "Conf1dant!"
    smtp_server = "smtp.office365.com"
    smtp_port = 587

    message = MIMEMultipart()
    message["From"] = f"{sender_name} <{sender_email}>"
    message["To"] = destination
    message["Subject"] = subject
    message.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, destination, message.as_string())
            print(f"Email sent successfully to {destination}")
            return 'success'
    except Exception as e:
        print(f"Failed to send email. Error: {e}")
        return f'failed: {e}'

# Authentication helper functions
def generate_verification_code():
    """Generate a random 4-digit verification code"""
    return f"{random.randint(0, 9999):04d}"

def clean_expired_codes():
    """Remove verification codes older than 10 minutes"""
    now = datetime.now()
    expired_emails = []

    for email, data in pending_codes.items():
        if now - data["timestamp"] > timedelta(minutes=10):
            expired_emails.append(email)

    for email in expired_emails:
        del pending_codes[email]

def send_verification_email(email, code):
    """Send verification code to user's email"""
    # For testing: always send to ash.nehru@gmail.com with actual email in subject
    actual_recipient = "ash.nehru@gmail.com"
    subject = f"{email} - Firefly Verification Code"
    body = f"""Your Firefly verification code is: {code}

This code will expire in 10 minutes.

(Testing: This email was requested for {email})

If you didn't request this code, you can safely ignore this email.
"""
    result = send_email(actual_recipient, subject, body)
    return result == 'success'

@app.route('/')
def index():
    """Serve the main page with the noob logo"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/ping', methods=['GET'])
def ping():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'message': 'Firefly server is running'
    })

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

    # Check if this is a new user (no devices yet)
    is_new_user = len(user.get('device_ids', [])) == 0

    # Add device to user
    success = db.add_device_to_user(user['id'], device_id)
    if not success:
        print(f"Warning: Failed to add device {device_id} to user {user['id']}")

    # Remove used code
    del pending_codes[email]

    print(f"User {email} authenticated successfully with device {device_id} (new_user: {is_new_user})")

    return jsonify({
        'status': 'success',
        'user_id': user['id'],
        'email': user['email'],
        'is_new_user': is_new_user
    })

def allowed_file(filename):
    """Check if uploaded file has an allowed extension"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/uploads/<filename>')
def serve_upload(filename):
    """Serve uploaded files"""
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

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

@app.route('/api/posts/recent', methods=['GET'])
def get_recent_posts():
    """Get recent posts"""
    try:
        limit = request.args.get('limit', 50, type=int)
        posts = db.get_recent_posts(limit=limit)

        return jsonify({
            'status': 'success',
            'posts': posts
        })
    except Exception as e:
        print(f"Error getting recent posts: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/posts/<int:post_id>', methods=['GET'])
def get_post(post_id):
    """Get a specific post by ID"""
    try:
        post = db.get_post_by_id(post_id)
        if not post:
            return jsonify({
                'status': 'error',
                'message': 'Post not found'
            }), 404

        return jsonify({
            'status': 'success',
            'post': post
        })
    except Exception as e:
        print(f"Error getting post: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/shutdown', methods=['POST'])
def shutdown():
    """Shutdown the server remotely"""
    # Send SIGTERM to the process
    os.kill(os.getpid(), signal.SIGTERM)
    return jsonify({
        'status': 'shutting down',
        'message': 'Server is shutting down'
    })

if __name__ == '__main__':
    # Run on all interfaces so it's accessible from network
    # Port 8080 as specified
    print("Starting Firefly server on http://0.0.0.0:8080")
    print(f"Local IP: http://192.168.1.76:8080")
    print(f"Public IP: http://185.96.221.52:8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
