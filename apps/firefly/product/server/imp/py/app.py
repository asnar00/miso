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

    # Check if user exists, create if not
    user = db.get_user_by_email(email)
    if not user:
        logger.info(f"Creating new user: {email}")
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
        logger.warning(f"Warning: Failed to add device {device_id} to user {user['id']}")

    # Remove used code
    del pending_codes[email]

    logger.info(f"User {email} authenticated successfully with device {device_id} (new_user: {is_new_user})")

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
            image_url=image_url
        )

        if not success:
            return jsonify({
                'status': 'error',
                'message': 'Failed to update post'
            }), 500

        logger.info(f"Updated post {post_id} by user {email} (ID: {user_id})")

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

@app.route('/api/posts/recent-tagged', methods=['GET'])
def get_recent_tagged_posts():
    """Get recent posts filtered by template tags and user"""
    try:
        tags_param = request.args.get('tags', '')
        by_user = request.args.get('by_user', 'any')
        user_email = request.args.get('user_email', '').strip().lower()
        limit = request.args.get('limit', 50, type=int)

        # Parse tags
        tags = [tag.strip() for tag in tags_param.split(',') if tag.strip()] if tags_param else []

        # Get current user ID if needed
        user_id = None
        if by_user == 'current' and user_email:
            user = db.get_user_by_email(user_email)
            if user:
                user_id = user['id']
            logger.info(f"[RECENT-TAGGED] by_user=current, email={user_email}, user_id={user_id}")

        # Fetch posts
        logger.info(f"[RECENT-TAGGED] Fetching: tags={tags}, user_id={user_id}, limit={limit}")
        posts = db.get_recent_tagged_posts(tags=tags, user_id=user_id, limit=limit)
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

        logger.info(f"Created profile {post_id} for user {email} (ID: {user_id})")

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

@app.route('/api/search', methods=['GET'])
def search_posts():
    """Search for posts using semantic similarity"""
    try:
        # Get query parameter
        query = request.args.get('q', '').strip()
        if not query:
            return jsonify({'error': 'Query parameter q is required'}), 400

        limit = int(request.args.get('limit', 20))

        logger.info(f"[SEARCH] Query: {query}, Limit: {limit}")

        # Load all embeddings
        all_embeddings, index = load_all_embeddings()
        logger.info(f"[SEARCH] Loaded {len(index)} fragments from {len(set(pid for pid, _ in index))} posts")

        # Generate query embedding
        model = embeddings.get_model()
        query_emb = model.encode([query], convert_to_numpy=True)[0]  # Shape: (768,)

        # Compute similarity scores
        scores = compute_similarity_gpu(query_emb, all_embeddings)

        # Group by post_id and take max score
        post_scores = {}
        for i, (post_id, frag_idx) in enumerate(index):
            if post_id not in post_scores:
                post_scores[post_id] = scores[i]
            else:
                post_scores[post_id] = max(post_scores[post_id], scores[i])

        # Sort by score
        ranked_posts = sorted(post_scores.items(), key=lambda x: x[1], reverse=True)

        # Filter out query posts and low-scoring results (check template_name in database)
        filtered_posts = []
        for post_id, score in ranked_posts:
            # Skip results with relevance score below 0.25
            if score < 0.25:
                continue
            post = db.get_post_by_id(post_id)
            if post and post.get('template_name') != 'query':
                filtered_posts.append((post_id, score))
            if len(filtered_posts) >= limit:
                break

        logger.info(f"[SEARCH] Top {len(filtered_posts)} posts (after filtering queries):")
        for post_id, score in filtered_posts[:5]:
            print(f"  Post {post_id}: {score:.3f}", file=sys.stderr, flush=True)

        # Return just post IDs and scores - client will fetch full details
        results = [{'id': post_id, 'relevance_score': float(score)} for post_id, score in filtered_posts]
        return jsonify(results)

    except Exception as e:
        logger.error(f"[SEARCH] Error: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500

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
    """Compute cosine similarity on GPU"""
    # Convert to PyTorch tensors on GPU
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    query_tensor = torch.tensor(query_emb_float, device=device).unsqueeze(0)
    all_tensor = torch.tensor(all_embeddings_float, device=device)

    # Compute cosine similarity
    scores = torch.nn.functional.cosine_similarity(query_tensor, all_tensor)

    return scores.cpu().numpy()

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
