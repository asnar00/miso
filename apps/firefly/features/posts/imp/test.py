#!/usr/bin/env python3
"""
Test script for posts feature
Tests post creation, retrieval, and listing
"""

import requests
import sys
import os
import re

SERVER_URL = "http://185.96.221.52:8080"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEST_POST_PATH = os.path.join(SCRIPT_DIR, 'test-post.md')

def parse_post_markdown(filepath):
    """Parse a post markdown file to extract title, summary, body, and image"""
    with open(filepath, 'r') as f:
        content = f.read()

    lines = content.split('\n')

    # Extract title (first line starting with #)
    title = None
    summary = None
    body_lines = []
    image_filename = None

    i = 0
    while i < len(lines):
        line = lines[i]

        # Title
        if line.startswith('# ') and not title:
            title = line[2:].strip()
            i += 1
            continue

        # Summary (emphasized line after title)
        if line.startswith('*') and line.endswith('*') and not summary:
            summary = line[1:-1].strip()
            i += 1
            continue

        # Extract image reference
        img_match = re.search(r'!\[.*?\]\((.*?)\)', line)
        if img_match and not image_filename:
            image_filename = img_match.group(1)

        # Everything else is body
        body_lines.append(line)
        i += 1

    # Join body lines and strip leading/trailing whitespace
    body = '\n'.join(body_lines).strip()

    return title, summary, body, image_filename

def test_create_post():
    """Test creating a post"""
    print("TEST: Creating a new post with image...")

    # Parse the test post markdown file
    title, summary, body, image_filename = parse_post_markdown(TEST_POST_PATH)

    print(f"  Title: {title}")
    print(f"  Summary: {summary}")
    print(f"  Image: {image_filename if image_filename else 'None'}")

    data = {
        'email': 'ash.nehru@gmail.com',
        'title': title,
        'summary': summary,
        'body': body,
        'timezone': 'Europe/Barcelona',
        'location_tag': 'Barcelona, Spain'
    }

    files = None
    if image_filename:
        image_path = os.path.join(SCRIPT_DIR, image_filename)
        if os.path.exists(image_path):
            files = {'image': open(image_path, 'rb')}
            print(f"  Uploading image: {image_path}")
        else:
            print(f"  Warning: Image not found at {image_path}")

    try:
        response = requests.post(f"{SERVER_URL}/api/posts/create", data=data, files=files, timeout=5)

        if response.status_code == 200:
            result = response.json()
            if result.get('status') == 'success':
                post_id = result.get('post_id')
                image_url = result.get('image_url')
                print(f"  ✓ Post created successfully (ID: {post_id})")
                if image_url:
                    print(f"  ✓ Image uploaded: {image_url}")
                return post_id, image_url
            else:
                print(f"  ✗ Failed: {result.get('message')}")
                return None, None
        else:
            print(f"  ✗ Server returned {response.status_code}")
            print(f"     {response.text}")
            return None, None

    except Exception as e:
        print(f"  ✗ Exception: {e}")
        return None, None
    finally:
        if files and files.get('image'):
            files['image'].close()

def test_get_post(post_id):
    """Test retrieving a specific post by ID"""
    print(f"\nTEST: Retrieving post {post_id}...")

    try:
        response = requests.get(f"{SERVER_URL}/api/posts/{post_id}", timeout=5)

        if response.status_code == 200:
            result = response.json()
            if result.get('status') == 'success':
                post = result.get('post')

                # Get expected values from test post
                title, summary, _, _ = parse_post_markdown(TEST_POST_PATH)

                # Verify fields
                checks = [
                    ('title', title),
                    ('summary', summary),
                    ('timezone', 'Europe/Barcelona'),
                    ('location_tag', 'Barcelona, Spain'),
                    ('user_id', 7)
                ]

                all_match = True
                for field, expected in checks:
                    actual = post.get(field)
                    if actual == expected:
                        print(f"  ✓ {field}: {actual}")
                    else:
                        print(f"  ✗ {field}: expected '{expected}', got '{actual}'")
                        all_match = False

                return all_match
            else:
                print(f"  ✗ Failed: {result.get('message')}")
                return False
        else:
            print(f"  ✗ Server returned {response.status_code}")
            return False

    except Exception as e:
        print(f"  ✗ Exception: {e}")
        return False

def test_get_recent_posts(expected_post_id):
    """Test getting recent posts"""
    print("\nTEST: Retrieving recent posts...")

    try:
        response = requests.get(f"{SERVER_URL}/api/posts/recent?limit=10", timeout=5)

        if response.status_code == 200:
            result = response.json()
            if result.get('status') == 'success':
                posts = result.get('posts', [])
                print(f"  ✓ Found {len(posts)} posts")

                # Check if our post is in the list
                found = any(post.get('id') == expected_post_id for post in posts)
                if found:
                    print(f"  ✓ Our post (ID: {expected_post_id}) is in the list")
                    return True
                else:
                    print(f"  ✗ Our post (ID: {expected_post_id}) not found in recent posts")
                    return False
            else:
                print(f"  ✗ Failed: {result.get('message')}")
                return False
        else:
            print(f"  ✗ Server returned {response.status_code}")
            return False

    except Exception as e:
        print(f"  ✗ Exception: {e}")
        return False

def main():
    """Run all tests"""
    print("=" * 60)
    print("POSTS FEATURE TEST")
    print("=" * 60)

    # Test 1: Create post
    post_id, image_url = test_create_post()
    if not post_id:
        print("\n❌ FAILED: Could not create post")
        sys.exit(1)

    # Test 2: Get post by ID
    if not test_get_post(post_id):
        print("\n❌ FAILED: Post retrieval or field verification failed")
        sys.exit(1)

    # Test 3: Get recent posts
    if not test_get_recent_posts(post_id):
        print("\n❌ FAILED: Post not found in recent posts")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED")
    if image_url:
        print(f"View post image at: {SERVER_URL}{image_url}")
    print("=" * 60)
    sys.exit(0)

if __name__ == '__main__':
    main()
