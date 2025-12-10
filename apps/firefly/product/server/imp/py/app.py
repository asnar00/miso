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
import sys
import numpy as np
import torch
import embeddings
import logging
import json
import hashlib
from anthropic import Anthropic
import config  # Load .env file
import threading
from apns_client import push_service

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# LLM model for search re-ranking
LLM_MODEL = "claude-3-5-haiku-20241022"

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

# In-memory storage for device logs
# Structure: {deviceId: {"deviceName": str, "appVersion": str, "buildNumber": str, "logs": str, "tunables": dict, "timestamp": datetime}}
device_logs = {}

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
    sender_password = config.get_config_value('EMAIL_PASSWORD')
    if not sender_password:
        logger.error("EMAIL_PASSWORD not set in .env file")
        return 'failed: EMAIL_PASSWORD not configured'
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
            logger.info(f"Email sent successfully to {destination}")
            return 'success'
    except Exception as e:
        logger.info(f"Failed to send email. Error: {e}")
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
    # For @example.com addresses, redirect to ash.nehru@gmail.com for testing
    if email.lower().endswith('@example.com'):
        actual_recipient = "ash.nehru@gmail.com"
        subject = f"{email} - microclub Verification Code"
        body = f"""Your microclub verification code is: {code}

This code will expire in 10 minutes.

(Testing: This email was requested for {email})

If you didn't request this code, you can safely ignore this email.
"""
    else:
        actual_recipient = email
        subject = "microclub Verification Code"
        body = f"""Your microclub verification code is: {code}

This code will expire in 10 minutes.

If you didn't request this code, you can safely ignore this email.
"""
    result = send_email(actual_recipient, subject, body)
    return result == 'success'

# Push notification helper functions

def notify_new_post(post, author):
    """Send push notifications when a new post is created"""
    if post.get('template_name') != 'post':
        return  # Only notify for regular posts

    author_id = author['id']
    author_name = author.get('name', 'Someone')

    # Get all users with push tokens except the author
    all_users = db.get_all_users_with_push_tokens()
    recipients = [u for u in all_users if u['id'] != author_id]

    if not recipients:
        logger.info(f"[PUSH] No recipients for new post notification")
        return

    # Check for query matches on this post
    post_embedding = post.get('embedding')
    user_query_matches = {}

    if post_embedding:
        # Find queries that match this post
        try:
            matching_queries = db.get_queries_matching_embedding(post_embedding, threshold=0.3)
            for q in matching_queries:
                query_user_id = q['user_id']
                if query_user_id not in user_query_matches and query_user_id != author_id:
                    user_query_matches[query_user_id] = q['title']
        except Exception as e:
            logger.error(f"[PUSH] Error finding matching queries: {e}")

    # Send notifications
    sent_count = 0
    for user in recipients:
        user_id = user['id']
        token = user['apns_device_token']

        if user_id in user_query_matches:
            # Consolidated notification mentioning query match
            query_title = user_query_matches[user_id]
            success = push_service.send_notification(
                token,
                title="New match",
                body=f"'{query_title}' matched a post from {author_name}"
            )
        else:
            # Standard new post notification
            success = push_service.send_notification(
                token,
                title="New post",
                body=f"New post from {author_name}"
            )

        if success:
            sent_count += 1

    logger.info(f"[PUSH] Sent new post notifications to {sent_count}/{len(recipients)} users")


def notify_new_user(new_user):
    """Send push notifications when a new user completes their profile"""
    new_user_id = new_user['id']
    new_user_name = new_user.get('name', 'Someone')

    # Get all users with push tokens except the new user
    all_users = db.get_all_users_with_push_tokens()
    recipients = [u for u in all_users if u['id'] != new_user_id]

    if not recipients:
        logger.info(f"[PUSH] No recipients for new user notification")
        return

    sent_count = 0
    for user in recipients:
        success = push_service.send_notification(
            user['apns_device_token'],
            title="New member",
            body=f"{new_user_name} just joined"
        )
        if success:
            sent_count += 1

    logger.info(f"[PUSH] Sent new user notifications to {sent_count}/{len(recipients)} users")


@app.route('/')
def index():
    """Serve the main page with the noob logo"""
    return render_template_string(HTML_TEMPLATE)

@app.route('/api/ping', methods=['GET'])
def ping():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'message': 'microclub server is running'
    })

@app.route('/api/version', methods=['GET'])
def get_version():
    """Return latest build number for version checking"""
    latest_build = int(config.get_config_value('LATEST_BUILD') or '0')
    testflight_url = config.get_config_value('TESTFLIGHT_URL') or 'https://testflight.apple.com/join/StN3xAMy'
    return jsonify({
        'latest_build': latest_build,
        'testflight_url': testflight_url
    })

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

@app.route('/api/invite', methods=['POST'])
def create_invite():
    """Create an invite for a new user"""
    data = request.get_json()
    device_id = data.get('device_id', '').strip()
    invitee_name = data.get('name', '').strip()
    invitee_email = data.get('email', '').strip().lower()

    if not device_id:
        return jsonify({'status': 'error', 'message': 'Device ID required'}), 400
    if not invitee_name:
        return jsonify({'status': 'error', 'message': 'Name required'}), 400
    if not invitee_email:
        return jsonify({'status': 'error', 'message': 'Email required'}), 400

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
    testflight_url = config.get_config_value('TESTFLIGHT_URL') or 'https://testflight.apple.com/join/StN3xAMy'

    if existing_user:
        logger.info(f"[Invite] User {invitee_email} already exists")
        return jsonify({
            'status': 'already_exists',
            'user_name': existing_user.get('name', ''),
            'testflight_link': testflight_url
        })

    # Create new user from invite (profile will be created when they tap "get started")
    new_user_id = db.create_user_from_invite(invitee_email, invitee_name, inviter['id'])
    if not new_user_id:
        return jsonify({'status': 'error', 'message': 'Failed to create user'}), 500

    # Decrement inviter's invite count
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE users SET num_invites = num_invites - 1 WHERE id = %s AND num_invites > 0", (inviter['id'],))
            conn.commit()
    finally:
        db.return_connection(conn)

    invite_message = f"Hi {invitee_name}! I'd like you to try microclub.\nDownload it here: {testflight_url}"

    logger.info(f"[Invite] User {inviter['id']} invited {invitee_email} (new user {new_user_id})")

    return jsonify({
        'status': 'invite_created',
        'testflight_link': testflight_url,
        'invite_message': invite_message
    })

@app.route('/api/health', methods=['GET'])
def health():
    """Detailed health check including database connectivity"""
    health_status = {
        'server': 'ok',
        'database': 'unknown',
        'timestamp': datetime.now().isoformat()
    }

    try:
        # Try to get a database connection
        conn = db.get_connection()
        if conn:
            health_status['database'] = 'ok'
            db.return_connection(conn)
        else:
            health_status['database'] = 'failed'
            health_status['status'] = 'degraded'
    except Exception as e:
        health_status['database'] = 'failed'
        health_status['database_error'] = str(e)
        health_status['status'] = 'degraded'
        logger.error(f"Health check database error: {e}")

    status_code = 200 if health_status.get('database') == 'ok' else 503
    return jsonify(health_status), status_code

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

    # Check if user exists - invitation only
    user = db.get_user_by_email(email)
    if not user:
        logger.info(f"User not found (invitation only): {email}")
        return jsonify({
            'status': 'error',
            'message': 'sorry, microclub is currently invitation only - to request an invite, email admin@microclub.org'
        }), 403

    # Generate and store code
    code = generate_verification_code()
    pending_codes[email] = {
        "code": code,
        "timestamp": datetime.now()
    }

    logger.info(f"Generated code {code} for {email}")

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

    # Verify code (accept test code "1324" for debugging)
    stored_data = pending_codes[email]
    if stored_data["code"] != code and code != "1324":
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
        logger.warning(f"Warning: Failed to add device {device_id} to user {user['id']}")

    # Remove used code
    del pending_codes[email]

    logger.info(f"User {email} authenticated successfully with device {device_id} (new_user: {is_new_user})")

    return jsonify({
        'status': 'success',
        'user_id': user['id'],
        'email': user['email'],
        'name': user.get('name', ''),
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

        # Get optional template_name (defaults to 'post')
        template_name = request.form.get('template_name', 'post').strip()

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

        # If parent_id not provided, default to user's profile post
        if parent_id is None:
            profile = db.get_user_profile(user_id)
            if profile:
                parent_id = profile['id']
                logger.info(f"[CREATE_POST] No parent_id provided, defaulting to user's profile post: {parent_id}")

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
                logger.info(f"Uploaded image: {filename}")

        # Create post in database
        logger.info(f"[CREATE_POST] Creating post: email={email}, user_id={user_id}, parent_id={parent_id}, title={title[:30]}..., template_name={template_name}")
        post_id = db.create_post(
            user_id=user_id,
            title=title,
            summary=summary,
            body=body,
            timezone=timezone,
            parent_id=parent_id,
            image_url=image_url,
            location_tag=location_tag,
            ai_generated=ai_generated,
            template_name=template_name
        )

        if not post_id:
            logger.info(f"[CREATE_POST] ERROR: db.create_post returned None/False")
            return jsonify({
                'status': 'error',
                'message': 'Failed to create post'
            }), 500

        logger.info(f"[CREATE_POST] Created post {post_id} by user {email} (ID: {user_id}), parent_id: {parent_id}")

        # Generate embeddings for the new post
        try:
            embeddings.generate_embeddings(post_id, title, summary, body)
            logger.info(f"[CREATE_POST] Generated embeddings for post {post_id}")
        except Exception as e:
            logger.error(f"[CREATE_POST] Failed to generate embeddings: {e}")

        # Background matching: check post against all queries (non-blocking)
        background_match_post(post_id)

        # If this is a query, populate initial results
        if template_name == 'query':
            try:
                populate_initial_query_results(post_id)
                logger.info(f"[CREATE_POST] Populated initial results for query {post_id}")
            except Exception as e:
                logger.error(f"[CREATE_POST] Failed to populate initial query results: {e}")

        # Fetch the created post to return it
        post = db.get_post_by_id(post_id)
        if not post:
            return jsonify({
                'status': 'error',
                'message': 'Post created but failed to retrieve'
            }), 500

        # Send push notifications for new posts (non-blocking)
        if template_name == 'post':
            try:
                notify_new_post(post, user)
            except Exception as e:
                logger.error(f"[CREATE_POST] Failed to send push notifications: {e}")

        return jsonify({
            'status': 'success',
            'post': post
        })

    except Exception as e:
        logger.error(f"Error creating post: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/posts/update', methods=['POST'])
def update_post():
    """Update an existing post"""
    try:
        # Get form data
        post_id_str = request.form.get('post_id', '').strip()
        email = request.form.get('email', '').strip().lower()
        title = request.form.get('title', '').strip()
        summary = request.form.get('summary', '').strip()
        body = request.form.get('body', '').strip()

        # Get optional clip offsets
        clip_offset_x_str = request.form.get('clip_offset_x', '').strip()
        clip_offset_y_str = request.form.get('clip_offset_y', '').strip()
        clip_offset_x = None
        clip_offset_y = None
        if clip_offset_x_str:
            try:
                clip_offset_x = max(-1.0, min(1.0, float(clip_offset_x_str)))
            except ValueError:
                pass
        if clip_offset_y_str:
            try:
                clip_offset_y = max(-1.0, min(1.0, float(clip_offset_y_str)))
            except ValueError:
                pass

        # Validate required fields
        if not post_id_str or not email or not title or not summary or not body:
            return jsonify({
                'status': 'error',
                'message': 'post_id, email, title, summary, and body are required'
            }), 400

        # Convert post_id to int
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

        # Get existing post to verify ownership
        existing_post = db.get_post_by_id(post_id)
        if not existing_post:
            return jsonify({
                'status': 'error',
                'message': 'Post not found'
            }), 404

        if existing_post['user_id'] != user_id:
            return jsonify({
                'status': 'error',
                'message': 'You can only edit your own posts'
            }), 403

        # Handle image upload if present
        image_url = existing_post['image_url']  # Keep existing image by default
        if 'image' in request.files:
            file = request.files['image']
            if file and file.filename and allowed_file(file.filename):
                # Generate unique filename
                ext = file.filename.rsplit('.', 1)[1].lower()
                filename = f"{uuid.uuid4().hex}.{ext}"
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                file.save(filepath)
                image_url = f"/uploads/{filename}"
                logger.info(f"Uploaded new image: {filename}")

                # TODO: Delete old image file if it exists

        # Update post in database
        success = db.update_post(
            post_id=post_id,
            title=title,
            summary=summary,
            body=body,
            image_url=image_url,
            clip_offset_x=clip_offset_x,
            clip_offset_y=clip_offset_y
        )

        if not success:
            return jsonify({
                'status': 'error',
                'message': 'Failed to update post'
            }), 500

        logger.info(f"Updated post {post_id} by user {email} (ID: {user_id})")

        # Regenerate embeddings
        try:
            embeddings.generate_embeddings(post_id, title, summary, body)
            logger.info(f"[UPDATE_POST] Regenerated embeddings for post {post_id}")
        except Exception as e:
            logger.error(f"[UPDATE_POST] Failed to regenerate embeddings: {e}")

        # If this is a query, clear and regenerate results
        if existing_post.get('template_name') == 'query':
            try:
                db.clear_query_results(post_id)
                populate_initial_query_results(post_id)
                logger.info(f"[UPDATE_POST] Regenerated results for query {post_id}")
            except Exception as e:
                logger.error(f"[UPDATE_POST] Failed to regenerate query results: {e}")
        else:
            # Regular post - re-check against all queries (non-blocking)
            background_match_post(post_id)

        # Fetch the updated post to return it
        post = db.get_post_by_id(post_id)
        if not post:
            return jsonify({
                'status': 'error',
                'message': 'Post updated but failed to retrieve'
            }), 500

        return jsonify({
            'status': 'success',
            'post': post
        })

    except Exception as e:
        logger.error(f"Error updating post: {e}", exc_info=True)
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
        logger.error(f"Error getting recent posts: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

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
        logger.error(f"Error getting recent users: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/new-since', methods=['GET'])
def get_new_users_since():
    """Check if there are new users (with complete profiles) since a given timestamp"""
    try:
        since = request.args.get('since', '')

        if not since:
            return jsonify({'has_new': False, 'count': 0})

        conn = db.get_connection()
        try:
            with conn.cursor() as cur:
                # Check for users whose profile was completed after the timestamp
                cur.execute("""
                    SELECT COUNT(*) FROM users
                    WHERE profile_complete = TRUE
                    AND profile_completed_at > %s
                """, (since,))
                count = cur.fetchone()[0]

                return jsonify({
                    'has_new': count > 0,
                    'count': count
                })
        finally:
            db.return_connection(conn)
    except Exception as e:
        logger.error(f"Error checking new users: {e}", exc_info=True)
        return jsonify({'has_new': False, 'count': 0})

@app.route('/api/posts/recent-tagged', methods=['GET'])
def get_recent_tagged_posts():
    """Get recent posts filtered by template tags and user"""
    try:
        tags_param = request.args.get('tags', '')
        by_user = request.args.get('by_user', 'any')
        user_email = request.args.get('user_email', '').strip().lower()
        limit = request.args.get('limit', 50, type=int)
        after = request.args.get('after', '').strip()  # ISO8601 timestamp

        # Parse tags
        tags = [tag.strip() for tag in tags_param.split(',') if tag.strip()] if tags_param else []

        # Get current user ID if needed
        user_id = None
        if by_user == 'current' and user_email:
            user = db.get_user_by_email(user_email)
            if user:
                user_id = user['id']
            logger.info(f"[RECENT-TAGGED] by_user=current, email={user_email}, user_id={user_id}")

        # Fetch posts (pass current_user_email for profile filtering)
        logger.info(f"[RECENT-TAGGED] Fetching: tags={tags}, user_id={user_id}, limit={limit}, user_email={user_email}, after={after}")
        posts = db.get_recent_tagged_posts(tags=tags, user_id=user_id, limit=limit, current_user_email=user_email, after=after if after else None)
        logger.info(f"[RECENT-TAGGED] Found {len(posts)} posts")

        return jsonify({
            'status': 'success',
            'posts': posts
        })
    except Exception as e:
        logger.error(f"Error getting recent tagged posts: {e}", exc_info=True)
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
        logger.error(f"Error getting post: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

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
        logger.error(f"Error reparenting post: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/posts/<int:post_id>/children', methods=['GET'])
def get_post_children(post_id):
    """Get all child posts of a specific post"""
    try:
        children = db.get_child_posts(post_id)

        return jsonify({
            'status': 'success',
            'post_id': post_id,
            'children': children,
            'count': len(children)
        })
    except Exception as e:
        logger.error(f"Error getting child posts: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/posts/<int:post_id>', methods=['DELETE'])
def delete_post(post_id):
    """Delete a post"""
    try:
        logger.info(f"[DELETE] Deleting post {post_id}")

        # Delete the post from database
        success = db.delete_post(post_id)

        if not success:
            return jsonify({
                'status': 'error',
                'message': 'Post not found or could not be deleted'
            }), 404

        # Delete embeddings if they exist
        import embeddings
        embeddings.delete_embeddings(post_id)

        logger.info(f"[DELETE] Successfully deleted post {post_id}")
        return jsonify({
            'status': 'success',
            'message': 'Post deleted successfully'
        })
    except Exception as e:
        logger.error(f"[DELETE] Error deleting post: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/<path:user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    """Get a user's profile post (user_id can be email or numeric ID)"""
    try:
        logger.info(f"[PROFILE] Fetching profile for user_id: {user_id}")

        # If user_id is an email, look up the numeric user ID
        if '@' in str(user_id):
            logger.info(f"[PROFILE] Looking up user by email: {user_id}")
            user = db.get_user_by_email(user_id)
            if not user:
                logger.info(f"[PROFILE] User not found: {user_id}")
                return jsonify({
                    'status': 'error',
                    'message': 'User not found'
                }), 404
            user_id = user['id']
            logger.info(f"[PROFILE] Found user ID: {user_id}")

        profile = db.get_user_profile(user_id)
        logger.info(f"[PROFILE] Profile result: {profile}")

        # If profile doesn't exist, create a blank one
        if profile is None:
            logger.info(f"[PROFILE] No profile found for user {user_id}, creating blank profile")
            try:
                profile_id = db.create_profile_post(
                    user_id=user_id,
                    title="",
                    summary="",
                    body="",
                    image_url=None,
                    timezone="UTC"
                )
                logger.info(f"[PROFILE] Created profile with ID: {profile_id}")
                if profile_id is None:
                    logger.info(f"[PROFILE] WARNING: create_profile_post returned None - check database logs")
                # Fetch the newly created profile
                profile = db.get_user_profile(user_id)
                logger.info(f"[PROFILE] Fetched newly created profile: {profile}")
            except Exception as create_error:
                logger.error(f"[PROFILE] Exception during profile creation: {create_error}", exc_info=True)

        return jsonify({
            'status': 'success',
            'profile': profile
        })
    except Exception as e:
        logger.error(f"[PROFILE] Error getting user profile: {e}", exc_info=True)
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

        # Validate required fields (summary and body can be empty for new profiles)
        if not email or not title:
            return jsonify({
                'status': 'error',
                'message': 'email and title are required'
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
                logger.info(f"Uploaded profile image: {filename}")

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

        # Mark user's profile as complete with timestamp (for notifications)
        conn = db.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE users SET profile_complete = TRUE, profile_completed_at = NOW() WHERE id = %s",
                    (user_id,)
                )
                conn.commit()
        finally:
            db.return_connection(conn)

        logger.info(f"Created profile {post_id} for user {email} (ID: {user_id})")

        # Send push notifications for new user (non-blocking)
        try:
            notify_new_user(user)
        except Exception as e:
            logger.error(f"[PROFILE] Failed to send push notifications: {e}")

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
        logger.error(f"Error creating profile: {e}", exc_info=True)
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
                logger.info(f"Uploaded new profile image: {filename}")

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

        logger.info(f"Updated profile {post_id} for user {email} (ID: {user_id})")

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
        logger.error(f"Error updating profile: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/templates/<template_name>', methods=['GET'])
def get_template(template_name):
    """Get template information including plural name"""
    conn = db.get_connection()
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
        logger.error(f"Error fetching template: {e}", exc_info=True)
        return jsonify({
            'status': 'error',
            'message': f'Server error: {str(e)}'
        }), 500
    finally:
        db.return_connection(conn)

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
        logger.warning(f"[PUSH] Device registration failed: user not found for device {device_id[:8]}...")
        return jsonify({'status': 'error', 'message': 'User not found'}), 404

    # Update their APNs token
    success = db.update_user_apns_token(user['id'], apns_token)
    if success:
        logger.info(f"[PUSH] Registered token for user {user['id']} ({user.get('name', 'unknown')}): {apns_token[:8]}...")
        return jsonify({'status': 'ok'})
    else:
        return jsonify({'status': 'error', 'message': 'Failed to update token'}), 500


@app.route('/api/notifications/poll', methods=['POST'])
def poll_notifications():
    """Unified polling endpoint for all notification badges
    Request body: {
        "user_email": "user@example.com",
        "query_ids": [1, 2, 3],
        "last_viewed_users": "2025-12-08T19:00:00Z",
        "last_viewed_posts": "2025-12-08T19:00:00Z"
    }
    Response: {
        "query_badges": {"1": true, "2": false},
        "has_new_users": true,
        "has_new_posts": true
    }"""
    try:
        data = request.get_json() or {}
        user_email = data.get('user_email', '')
        query_ids = data.get('query_ids', [])
        last_viewed_users = data.get('last_viewed_users', '')
        last_viewed_posts = data.get('last_viewed_posts', '')

        result = {
            'query_badges': {},
            'has_new_users': False,
            'has_new_posts': False
        }

        # 1. Check query badges (if any query_ids provided)
        if query_ids and user_email:
            flags = db.get_has_new_matches_bulk(user_email, query_ids)
            result['query_badges'] = {str(k): v for k, v in flags.items()}

        conn = db.get_connection()
        try:
            with conn.cursor() as cur:
                # 2. Check for new users (if timestamp provided)
                if last_viewed_users:
                    cur.execute("""
                        SELECT COUNT(*) FROM users
                        WHERE profile_complete = TRUE
                        AND profile_completed_at > %s
                    """, (last_viewed_users,))
                    count = cur.fetchone()[0]
                    result['has_new_users'] = count > 0

                # 3. Check for new posts by other users (if timestamp and email provided)
                if last_viewed_posts and user_email:
                    cur.execute("""
                        SELECT COUNT(*) FROM posts p
                        JOIN users u ON p.user_id = u.id
                        WHERE p.template_name = 'post'
                        AND p.created_at > %s
                        AND u.email != %s
                    """, (last_viewed_posts, user_email))
                    count = cur.fetchone()[0]
                    result['has_new_posts'] = count > 0
        finally:
            db.return_connection(conn)

        return jsonify(result), 200
    except Exception as e:
        logger.error(f"[NOTIFICATIONS] Error polling: {e}", exc_info=True)
        return jsonify({'query_badges': {}, 'has_new_users': False, 'has_new_posts': False}), 200


@app.route('/api/queries/badges', methods=['POST'])
def get_query_badges():
    """Get has_new_matches flags for multiple queries for a user
    Request body: {"user_email": "user@example.com", "query_ids": [1, 2, 3, ...]}
    Response: {"1": true, "2": false, ...}"""
    try:
        data = request.get_json()
        user_email = data.get('user_email', '')
        query_ids = data.get('query_ids', [])

        if not user_email:
            return jsonify({'error': 'user_email is required'}), 400

        if not query_ids:
            return jsonify({}), 200

        # Get flags from database for this user
        flags = db.get_has_new_matches_bulk(user_email, query_ids)

        # Convert to string keys for JSON
        response = {str(k): v for k, v in flags.items()}

        return jsonify(response), 200
    except Exception as e:
        logger.error(f"[BADGES] Error getting badges: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/search', methods=['GET'])
def search_posts():
    """Get cached search results for a query (instant, with auto-populate fallback)"""
    try:
        query_id = request.args.get('query_id', '').strip()
        user_email = request.args.get('user_email', '').strip()

        if not query_id:
            return jsonify({'error': 'Query parameter query_id is required'}), 400

        query_id = int(query_id)
        logger.info(f"[SEARCH] Getting cached results for query {query_id}")

        # Read cached results
        results = db.get_query_results(query_id)

        # If cache is empty, populate it now
        if len(results) == 0:
            logger.info(f"[SEARCH] Cache empty for query {query_id}, populating now...")
            populate_initial_query_results(query_id)
            # Read again after population
            results = db.get_query_results(query_id)
            logger.info(f"[SEARCH] Populated cache with {len(results)} results")

        # Record that this user viewed this query
        if user_email:
            db.record_query_view(user_email, query_id)

        # Return IDs and scores (client fetches full posts)
        response = [{
            'id': post_id,
            'relevance_score': score / 100  # Normalize to 0-1 range
        } for post_id, score, _ in results]

        logger.info(f"[SEARCH] Returning {len(response)} cached results")
        return jsonify(response)

    except Exception as e:
        logger.error(f"[SEARCH] Error: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500


def populate_initial_query_results(query_id):
    """
    When a new query is created, search all existing posts and cache results.
    This is the one-time "slow" operation (may take several seconds).
    """
    try:
        logger.info(f"[SEARCH] Populating initial results for new query {query_id}")

        # Fetch the query post
        query_post = db.get_post_by_id(query_id)
        if not query_post:
            logger.error(f"Query post {query_id} not found")
            return

        # Load query embeddings from disk
        query_embeddings = embeddings.load_embeddings(query_id)
        if query_embeddings is None:
            logger.error(f"No embeddings for query {query_id}")
            return

        # Convert to float32
        query_embeddings = query_embeddings.astype(np.float32) / 127.0

        logger.info(f"[SEARCH] Loaded query embeddings: {query_embeddings.shape[0]} fragments")

        # Load all post embeddings
        all_embeddings, index = load_all_embeddings()
        all_embeddings = all_embeddings.astype(np.float32) / 127.0
        logger.info(f"[SEARCH] Loaded {len(index)} fragments from {len(set(pid for pid, _ in index))} posts")

        # Compute similarity matrix
        similarity_matrix = compute_similarity_gpu_matrix(query_embeddings, all_embeddings)

        # Aggregate scores per post using MAX
        post_similarities = {}
        for i, (post_id, frag_idx) in enumerate(index):
            if post_id == query_id:
                continue  # Skip query itself

            # Get similarities between all query fragments and this post fragment
            fragment_sims = similarity_matrix[:, i]

            if post_id not in post_similarities:
                post_similarities[post_id] = []
            post_similarities[post_id].extend(fragment_sims.tolist())

        # Compute MAX score for each post
        post_scores = {
            post_id: max(sims)
            for post_id, sims in post_similarities.items()
        }

        # Sort and get top 20 candidates
        ranked = sorted(post_scores.items(), key=lambda x: x[1], reverse=True)
        rag_candidates = ranked[:20]

        logger.info(f"[SEARCH] RAG top 20 candidates")

        # Fetch full post content for candidates
        candidate_posts = []
        for post_id, rag_score in rag_candidates:
            post = db.get_post_by_id(post_id)
            if post and post.get('template_name') != 'query':
                candidate_posts.append({
                    'id': post_id,
                    'title': post.get('title', ''),
                    'summary': post.get('summary', ''),
                    'body': post.get('body', ''),
                    'rag_score': rag_score
                })

        # LLM re-ranking (batch mode)
        try:
            llm_results = llm_rerank_posts(query_post, candidate_posts)

            # Store results (llm_results format: [{'id': post_id, 'score': int}, ...])
            matches_added = False
            for item in llm_results:
                if item['score'] >= 40:
                    db.insert_query_result(query_id, item['id'], item['score'])
                    matches_added = True

            if matches_added:
                db.update_last_match_added(query_id)

            logger.info(f"[SEARCH] Stored {len([item for item in llm_results if item['score'] >= 40])} LLM-scored results")

        except Exception as e:
            # LLM failed, use RAG scores
            logger.warning(f"[SEARCH] LLM re-ranking failed: {e}, using RAG scores")

            if candidate_posts:
                for post in candidate_posts:
                    db.insert_query_result(query_id, post['id'], post['rag_score'] * 100)
                db.update_last_match_added(query_id)

            logger.info(f"[SEARCH] Stored {len(candidate_posts)} RAG-scored results")

    except Exception as e:
        logger.error(f"[SEARCH] Error populating initial query results: {e}", exc_info=True)


def background_match_post(post_id):
    """
    Run check_post_against_queries in a background thread.
    This prevents blocking the HTTP response.
    """
    def run():
        try:
            check_post_against_queries(post_id)
        except Exception as e:
            logger.error(f"[BACKGROUND] Error in background matching for post {post_id}: {e}", exc_info=True)

    thread = threading.Thread(target=run, daemon=True)
    thread.start()
    logger.info(f"[BACKGROUND] Started background matching thread for post {post_id}")


def check_post_against_queries(new_post_id):
    """
    Check a newly created post against all queries and cache matches.
    Runs in background after post creation.
    """
    try:
        logger.info(f"[SEARCH] Checking post {new_post_id} against all queries")

        # 0. Clear any existing results for this post (in case it's being re-evaluated)
        db.clear_post_from_results(new_post_id)

        # 1. Get all queries
        queries = db.get_posts_by_template('query')
        if len(queries) == 0:
            logger.info("[SEARCH] No queries to check against")
            return

        # 2. Load new post embeddings
        new_post_embeddings = embeddings.load_embeddings(new_post_id)
        if new_post_embeddings is None:
            logger.warning(f"No embeddings found for post {new_post_id}")
            return

        # Convert to float32
        new_post_embeddings = new_post_embeddings.astype(np.float32) / 127.0

        # 3. Compute similarity against each query
        query_scores = []

        for query in queries:
            query_id = query[0]  # id is first column

            # Load query embeddings
            query_embeddings = embeddings.load_embeddings(query_id)
            if query_embeddings is None:
                continue

            query_embeddings = query_embeddings.astype(np.float32) / 127.0

            # Compute similarity matrix
            similarity_matrix = compute_similarity_gpu_matrix(query_embeddings, new_post_embeddings)

            # Use MAX aggregation
            max_similarity = np.max(similarity_matrix)

            query_scores.append((query_id, query, max_similarity))

        # 4. Sort by RAG score
        query_scores.sort(key=lambda x: x[2], reverse=True)

        # 5. Get new post data
        new_post = db.get_post_by_id(new_post_id)

        # 6. Process in batches of 20
        BATCH_SIZE = 20
        logger.info(f"[SEARCH] Processing {len(query_scores)} queries in {(len(query_scores) + BATCH_SIZE - 1) // BATCH_SIZE} batches")

        for batch_start in range(0, len(query_scores), BATCH_SIZE):
            batch = query_scores[batch_start:batch_start + BATCH_SIZE]
            batch_num = batch_start // BATCH_SIZE + 1

            logger.info(f"[SEARCH] Batch {batch_num}: Evaluating post {new_post_id} against {len(batch)} queries")

            try:
                # Call LLM to evaluate post against batch of queries
                batch_scores = llm_evaluate_post_against_queries(batch, new_post)

                # Store matches if relevant (score >= 40)
                matches_stored = 0
                for query_id, llm_score in batch_scores:
                    if llm_score >= 40:
                        db.insert_query_result(query_id, new_post_id, llm_score)
                        db.update_last_match_added(query_id)
                        matches_stored += 1
                        logger.info(f"[SEARCH]   Query {query_id}: score {llm_score} - MATCH stored")
                    else:
                        logger.debug(f"[SEARCH]   Query {query_id}: score {llm_score} - below threshold")

                logger.info(f"[SEARCH] Batch {batch_num}: stored {matches_stored}/{len(batch)} matches")

            except Exception as e:
                # LLM failed, fall back to RAG scores
                logger.warning(f"[SEARCH] LLM batch evaluation failed: {e}, using RAG scores")

                for query_id, query, rag_score in batch:
                    if rag_score >= 0.4:  # Equivalent to 40/100
                        db.insert_query_result(query_id, new_post_id, rag_score * 100)
                        db.update_last_match_added(query_id)

    except Exception as e:
        logger.error(f"[SEARCH] Error checking post against queries: {e}", exc_info=True)


def llm_evaluate_post_against_queries(query_batch, new_post):
    """
    Evaluate how relevant a new post is to a batch of queries.

    Args:
        query_batch: List of (query_id, query_row, rag_score) tuples
        new_post: Dict with 'title', 'summary', 'body'

    Returns:
        List of (query_id, score) tuples
    """
    try:
        # Get API key from config
        api_key = config.get_anthropic_api_key()
        if not api_key:
            raise Exception("ANTHROPIC_API_KEY not found in environment")

        # Initialize Anthropic client
        client = Anthropic(api_key=api_key)

        # Build prompt
        prompt = "You are a semantic search relevance evaluator. Below are search queries from users looking for specific content.\n\n"

        for query_id, query_row, rag_score in query_batch:
            # Extract query text from row (columns: id, user_id, parent_id, title, summary, body, ...)
            title = query_row[3]
            summary = query_row[4]
            body = query_row[5]
            query_text = f"{title} {summary} {body}"
            prompt += f"Query {query_id}: {query_text}\n\n"

        prompt += f"""A new post has just been created:
Title: {new_post['title']}
Summary: {new_post['summary']}
Body: {new_post['body']}

For EACH query above, score 0-100: Does this new post answer or match what that query is searching for? Would someone who created that query want to see this post in their results?

Evaluate each query:
- Does the post provide relevant information the query is looking for?
- Does it match the semantic intent and topic of the query?
- Would the query author find this post useful?

Return ONLY a JSON array with this exact format:
[{{"query_id": <id>, "score": <0-100>}}, ...]

Score from 0-100 where:
- 0-39: Not relevant (query author wouldn't want to see this)
- 40-59: Somewhat relevant
- 60-79: Relevant
- 80-100: Highly relevant (exactly what the query is looking for)

Include ALL queries in your response, even if score is 0.
"""

        logger.info(f"[LLM] Sending post-to-queries prompt (batch of {len(query_batch)} queries)")
        logger.debug(f"[LLM] Prompt:\n{prompt}")

        response = client.messages.create(
            model=LLM_MODEL,
            max_tokens=1000,
            temperature=0.0,
            messages=[{"role": "user", "content": prompt}]
        )

        logger.info(f"[LLM] Response received")

        # Parse JSON response
        response_text = response.content[0].text
        logger.info(f"[LLM] Raw response: {response_text[:500]}...")

        # Extract JSON from response
        json_text = response_text.strip()
        if "```json" in json_text:
            json_start = json_text.find("```json") + 7
            json_end = json_text.find("```", json_start)
            json_text = json_text[json_start:json_end].strip()
        elif "```" in json_text:
            json_start = json_text.find("```") + 3
            json_end = json_text.find("```", json_start)
            json_text = json_text[json_start:json_end].strip()
        else:
            # Find JSON array and extract just the array
            array_start = json_text.find('[')
            if array_start >= 0:
                # Find the matching closing bracket
                bracket_count = 0
                for i in range(array_start, len(json_text)):
                    if json_text[i] == '[':
                        bracket_count += 1
                    elif json_text[i] == ']':
                        bracket_count -= 1
                        if bracket_count == 0:
                            json_text = json_text[array_start:i+1]
                            break

        logger.info(f"[LLM] Extracted JSON: {json_text[:200]}...")
        scores = json.loads(json_text)
        logger.info(f"[LLM] Parsed {len(scores)} scores successfully")
        return [(item['query_id'], item['score']) for item in scores]

    except Exception as e:
        logger.error(f"[LLM] Post-to-queries evaluation failed: {e}", exc_info=True)
        raise


def load_all_embeddings():
    """Load all post embeddings from disk"""
    embedding_files = []
    for filename in os.listdir('data/embeddings'):
        if filename.startswith('post_') and filename.endswith('.npy'):
            post_id = int(filename.replace('post_', '').replace('.npy', ''))
            embedding_files.append((post_id, f'data/embeddings/{filename}'))

    embedding_files.sort()

    all_embeddings = []
    index = []

    for post_id, filepath in embedding_files:
        emb = np.load(filepath)
        all_embeddings.append(emb)
        for frag_idx in range(emb.shape[0]):
            index.append((post_id, frag_idx))

    all_embeddings = np.vstack(all_embeddings)
    return all_embeddings, index

def compute_similarity_gpu(query_emb_float, all_embeddings_float):
    """Compute cosine similarity on GPU (single query vector vs all post vectors)"""
    # Convert to PyTorch tensors on GPU
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    query_tensor = torch.tensor(query_emb_float, device=device).unsqueeze(0)
    all_tensor = torch.tensor(all_embeddings_float, device=device)

    # Compute cosine similarity
    scores = torch.nn.functional.cosine_similarity(query_tensor, all_tensor)

    return scores.cpu().numpy()

def compute_similarity_gpu_matrix(query_embeddings, all_embeddings):
    """
    Compute cosine similarity matrix on GPU.

    Args:
        query_embeddings: numpy array of shape (num_query_fragments, 768)
        all_embeddings: numpy array of shape (num_all_fragments, 768)

    Returns:
        numpy array of shape (num_query_fragments, num_all_fragments)
        where result[i,j] = similarity between query fragment i and post fragment j
    """
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'

    # Convert to PyTorch tensors
    query_tensor = torch.tensor(query_embeddings, device=device)  # (num_query_frags, 768)
    all_tensor = torch.tensor(all_embeddings, device=device)      # (num_all_frags, 768)

    # Normalize for cosine similarity
    query_norm = torch.nn.functional.normalize(query_tensor, p=2, dim=1)
    all_norm = torch.nn.functional.normalize(all_tensor, p=2, dim=1)

    # Compute similarity matrix: (num_query_frags, 768) @ (768, num_all_frags)
    similarity_matrix = torch.mm(query_norm, all_norm.t())

    return similarity_matrix.cpu().numpy()

def build_reranking_prompt(query_post, candidate_posts):
    """Build prompt for Claude to re-rank search results"""
    prompt = f"""You are a semantic search relevance evaluator. Given a search query and a list of posts, score each post's relevance to the query from 0-100.

Query:
Title: {query_post.get('title', '')}
Summary: {query_post.get('summary', '')}
Detail: {query_post.get('body', '')}

IMPORTANT: Score based on DIRECT relevance to the query topic. Posts must contain actual content about the query subject, not just tangential associations or superficial word matches.

Posts to evaluate:
"""

    for post in candidate_posts:
        prompt += f"""
Post ID {post['id']}:
Title: {post.get('title', '')}
Summary: {post.get('summary', '')}
Body: {post.get('body', '')}
---
"""

    prompt += """
For each post, evaluate:
- Does the post DIRECTLY address the query topic?
- Is there concrete, specific content related to the query?
- Would someone searching for this query find this post genuinely useful?

Return ONLY a JSON array with this exact format:
[{"id": <post_id>, "score": <0-100>}, ...]

Score from 0-100 where:
- 0-39: Not relevant - no meaningful connection to query topic
- 40-59: Somewhat relevant - mentions related concepts but not the main topic
- 60-79: Relevant - directly addresses the query topic
- 80-100: Highly relevant - comprehensive, specific content about the query topic

Sort by score descending (highest first).
"""

    return prompt

def get_cached_llm_results(prompt, model_name):
    """Check cache for LLM results"""
    try:
        # Compute prompt hash
        prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

        # Query database
        conn = db.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT llm_results FROM search_cache
            WHERE prompt_hash = %s AND model_name = %s
        """, (prompt_hash, model_name))

        result = cursor.fetchone()
        db.return_connection(conn)

        if result:
            llm_results = json.loads(result[0])
            logger.info(f"[CACHE] ✓ HIT for hash {prompt_hash[:8]}... ({len(llm_results)} results)")
            return llm_results

        logger.info(f"[CACHE] ✗ MISS for hash {prompt_hash[:8]}...")
        return None

    except Exception as e:
        logger.error(f"[CACHE] Error reading cache: {e}")
        return None

def store_llm_results(prompt, model_name, llm_results):
    """Store LLM results in cache"""
    try:
        # Compute prompt hash
        prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

        # Serialize results
        results_json = json.dumps(llm_results)

        # Insert into database
        conn = db.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO search_cache (prompt_hash, model_name, llm_results)
            VALUES (%s, %s, %s)
            ON CONFLICT (prompt_hash) DO NOTHING
        """, (prompt_hash, model_name, results_json))

        conn.commit()
        db.return_connection(conn)

        logger.info(f"[CACHE] Stored results for hash {prompt_hash[:8]}...")

    except Exception as e:
        logger.error(f"[CACHE] Error storing cache: {e}")

def llm_rerank_posts(query_post, candidate_posts):
    """Use Claude Haiku to re-rank search results"""
    try:
        # Get API key from config
        api_key = config.get_anthropic_api_key()
        if not api_key:
            raise Exception("ANTHROPIC_API_KEY not found in environment")

        # Initialize Anthropic client
        client = Anthropic(api_key=api_key)

        # Build prompt
        prompt = build_reranking_prompt(query_post, candidate_posts)

        logger.info(f"[LLM] Prompt being sent to Claude:\n{prompt}")

        # CHECK CACHE FIRST
        cached_results = get_cached_llm_results(prompt, LLM_MODEL)
        if cached_results is not None:
            return cached_results

        # Call Claude Haiku API
        import time
        logger.info("[LLM] Calling Claude Haiku for re-ranking...")
        start_time = time.time()
        response = client.messages.create(
            model=LLM_MODEL,
            max_tokens=2000,
            temperature=0.0,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )
        end_time = time.time()
        api_duration = end_time - start_time
        logger.info(f"[LLM] API call completed in {api_duration:.2f} seconds")

        # Parse JSON response
        response_text = response.content[0].text
        logger.info(f"[LLM] Raw response: {response_text}")

        # Extract JSON from response (handle potential markdown code blocks and extra text)
        json_text = response_text.strip()

        if "```json" in json_text:
            json_start = json_text.find("```json") + 7
            json_end = json_text.find("```", json_start)
            json_text = json_text[json_start:json_end].strip()
        elif "```" in json_text:
            json_start = json_text.find("```") + 3
            json_end = json_text.find("```", json_start)
            json_text = json_text[json_start:json_end].strip()
        else:
            # Find the JSON array start (may have explanatory text before it)
            array_start = json_text.find('[')
            if array_start >= 0:
                json_text = json_text[array_start:]
                # Find matching closing bracket
                bracket_count = 0
                for i, char in enumerate(json_text):
                    if char == '[':
                        bracket_count += 1
                    elif char == ']':
                        bracket_count -= 1
                        if bracket_count == 0:
                            json_text = json_text[:i+1]
                            break

        logger.info(f"[LLM] Extracted JSON text: {json_text[:200]}...")
        scores = json.loads(json_text)
        logger.info(f"[LLM] Successfully parsed {len(scores)} scores")

        # STORE IN CACHE
        store_llm_results(prompt, LLM_MODEL, scores)

        return scores

    except Exception as e:
        logger.error(f"[LLM] Re-ranking failed: {e}", exc_info=True)
        raise

@app.route('/api/restart', methods=['POST'])
def restart():
    """Restart the server (triggers background restart script)"""
    logger.info("Restart requested via /api/restart endpoint")

    # Create marker file to indicate intentional shutdown
    marker_file = os.path.join(os.path.dirname(__file__), '.intentional_shutdown')
    try:
        with open(marker_file, 'w') as f:
            f.write(f"{datetime.now().isoformat()}\n")
        logger.info(f"Created intentional shutdown marker: {marker_file}")
    except Exception as e:
        logger.error(f"Failed to create shutdown marker: {e}")

    # Trigger background restart script
    script_dir = os.path.dirname(__file__)
    restart_script = os.path.join(script_dir, 'auto-restart.sh')
    try:
        # Launch restart script in background (it will wait, then restart us)
        import subprocess
        subprocess.Popen([restart_script],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        start_new_session=True)
        logger.info("Background restart script launched")
    except Exception as e:
        logger.error(f"Failed to launch restart script: {e}")

    return jsonify({
        'status': 'restarting',
        'message': 'Server is restarting (will be back in ~5 seconds)'
    })

@app.route('/api/shutdown', methods=['POST'])
def shutdown():
    """Shutdown the server remotely"""
    logger.info("Shutdown requested via /api/shutdown endpoint")

    # Create marker file to indicate intentional shutdown
    marker_file = os.path.join(os.path.dirname(__file__), '.intentional_shutdown')
    try:
        with open(marker_file, 'w') as f:
            f.write(f"{datetime.now().isoformat()}\n")
        logger.info(f"Created intentional shutdown marker: {marker_file}")
    except Exception as e:
        logger.error(f"Failed to create shutdown marker: {e}")

    # Send SIGTERM to the process
    os.kill(os.getpid(), signal.SIGTERM)
    return jsonify({
        'status': 'shutting down',
        'message': 'Server is shutting down'
    })

@app.route('/api/debug/logs', methods=['POST'])
def upload_debug_logs():
    """Receive and store logs from a device"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        device_id = data.get('deviceId')
        if not device_id:
            return jsonify({"error": "Missing deviceId"}), 400

        # Store/update device logs
        device_logs[device_id] = {
            "deviceName": data.get('deviceName', 'Unknown'),
            "appVersion": data.get('appVersion', 'Unknown'),
            "buildNumber": data.get('buildNumber', 'Unknown'),
            "logs": data.get('logs', ''),
            "tunables": data.get('tunables', {}),
            "timestamp": datetime.now()
        }

        logger.info(f"[DebugLogs] Received logs from device {device_id} ({data.get('deviceName', 'Unknown')})")
        return jsonify({"status": "ok"}), 200

    except Exception as e:
        logger.error(f"[DebugLogs] Error receiving logs: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/debug/logs', methods=['GET'])
def list_debug_logs():
    """List all devices that have uploaded logs"""
    devices = []
    for device_id, data in device_logs.items():
        devices.append({
            "deviceId": device_id,
            "deviceName": data["deviceName"],
            "appVersion": data["appVersion"],
            "buildNumber": data["buildNumber"],
            "timestamp": data["timestamp"].isoformat(),
            "logSize": len(data["logs"])
        })
    return jsonify(devices), 200

@app.route('/api/debug/logs/<device_id>', methods=['GET'])
def get_debug_logs(device_id):
    """Get logs for a specific device"""
    if device_id not in device_logs:
        return jsonify({"error": "Device not found"}), 404

    data = device_logs[device_id]
    return jsonify({
        "deviceId": device_id,
        "deviceName": data["deviceName"],
        "appVersion": data["appVersion"],
        "buildNumber": data["buildNumber"],
        "logs": data["logs"],
        "tunables": data["tunables"],
        "timestamp": data["timestamp"].isoformat()
    }), 200

def handle_sigterm(signum, frame):
    """Handle SIGTERM signal for graceful shutdown"""
    logger.info(f"Received signal {signum} (SIGTERM), shutting down gracefully")
    sys.exit(0)

def startup_health_check():
    """Perform health checks before starting the server"""
    logger.info("=" * 60)
    logger.info("Performing startup health checks...")
    logger.info("=" * 60)

    # Check 1: PostgreSQL is running
    logger.info("[HEALTH] Checking PostgreSQL status...")
    if not db.check_postgresql_running():
        logger.warning("[HEALTH] PostgreSQL is not running, attempting to start...")
        if db.restart_postgresql():
            logger.info("[HEALTH] PostgreSQL started successfully")
        else:
            logger.critical("[HEALTH] Failed to start PostgreSQL - server cannot start")
            sys.exit(1)
    else:
        logger.info("[HEALTH] PostgreSQL is running")

    # Check 2: Initialize database connection pool
    logger.info("[HEALTH] Initializing database connection pool...")
    try:
        db.initialize_pool()
        logger.info("[HEALTH] Database connection pool initialized successfully")
    except Exception as e:
        logger.critical(f"[HEALTH] Failed to initialize database pool: {e}")
        logger.critical("[HEALTH] Server cannot start without database connection")
        sys.exit(1)

    # Check 3: Test database connection
    logger.info("[HEALTH] Testing database connection...")
    try:
        conn = db.get_connection()
        db.return_connection(conn)
        logger.info("[HEALTH] Database connection test successful")
    except Exception as e:
        logger.critical(f"[HEALTH] Database connection test failed: {e}")
        sys.exit(1)

    # Run migrations
    logger.info("[HEALTH] Running migrations...")
    try:
        db.migrate_add_clip_offsets()
        logger.info("[HEALTH] Migrations complete")
    except Exception as e:
        logger.warning(f"[HEALTH] Migration warning: {e}")

    # Check 4: Create search_cache table if needed
    logger.info("[HEALTH] Creating search_cache table if needed...")
    try:
        db.create_search_cache_table()
        logger.info("[HEALTH] Search cache table ready")
    except Exception as e:
        logger.warning(f"[HEALTH] Failed to create search_cache table: {e}")
        logger.warning("[HEALTH] Search caching will be disabled")

    # Check 5: Create query_results table if needed
    logger.info("[HEALTH] Creating query_results table if needed...")
    try:
        db.create_query_results_table()
        logger.info("[HEALTH] Query results table ready")
    except Exception as e:
        logger.warning(f"[HEALTH] Failed to create query_results table: {e}")
        logger.warning("[HEALTH] Query result caching will be disabled")

    logger.info("=" * 60)
    logger.info("[HEALTH] All startup checks passed!")
    logger.info("=" * 60)

if __name__ == '__main__':
    # Register signal handler
    signal.signal(signal.SIGTERM, handle_sigterm)

    # Perform startup health checks
    startup_health_check()

    # Log startup information
    logger.info("=" * 60)
    logger.info("Starting Firefly server")
    logger.info(f"Host: 0.0.0.0")
    logger.info(f"Port: 8080")
    logger.info(f"Debug mode: False")
    logger.info(f"Local IP: http://192.168.1.76:8080")
    logger.info(f"Public IP: http://185.96.221.52:8080")
    logger.info(f"Upload folder: {UPLOAD_FOLDER}")
    logger.info(f"Max file size: {app.config['MAX_CONTENT_LENGTH'] / (1024*1024):.0f}MB")
    logger.info("=" * 60)

    try:
        app.run(host='0.0.0.0', port=8080, debug=False)
    except Exception as e:
        logger.critical(f"Fatal error during server execution: {e}", exc_info=True)
        sys.exit(1)
    finally:
        logger.info("Server stopped")
