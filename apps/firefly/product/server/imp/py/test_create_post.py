#!/usr/bin/env python3
"""
Test script to create a post in Firefly
"""

import requests

SERVER_URL = "http://185.96.221.52:8080"

def create_test_post():
    """Create a test post"""
    # Note: Using user_id=1, assuming user exists from previous auth testing
    data = {
        'user_id': '1',
        'title': 'My First Firefly Post',
        'summary': 'Testing the post creation feature',
        'body': '''This is my first post on Firefly!

I'm testing out the new post creation feature. This supports markdown, so I can do things like:

- Make lists
- **Bold text**
- *Italic text*

Pretty cool! Let's see how this renders on the iPhone.''',
        'timezone': 'America/Los_Angeles',
        'location_tag': 'San Francisco, CA'
    }

    print("Creating post...")
    print(f"Title: {data['title']}")
    print(f"Summary: {data['summary']}")

    response = requests.post(f"{SERVER_URL}/api/posts/create", data=data)

    if response.status_code == 200:
        result = response.json()
        print(f"\n✓ Post created successfully!")
        print(f"  Post ID: {result['post_id']}")
        if result['image_url']:
            print(f"  Image URL: {result['image_url']}")
    else:
        print(f"\n✗ Failed to create post")
        print(f"  Status: {response.status_code}")
        print(f"  Response: {response.text}")
        return None

    return result['post_id']

def get_recent_posts():
    """Get recent posts"""
    print("\nFetching recent posts...")

    response = requests.get(f"{SERVER_URL}/api/posts/recent?limit=10")

    if response.status_code == 200:
        result = response.json()
        posts = result['posts']
        print(f"\n✓ Found {len(posts)} posts:")

        for post in posts:
            print(f"\n  [{post['id']}] {post['title']}")
            print(f"      {post['summary']}")
            print(f"      Created: {post['created_at']}")
            print(f"      User ID: {post['user_id']}")
    else:
        print(f"\n✗ Failed to get posts")
        print(f"  Status: {response.status_code}")
        print(f"  Response: {response.text}")

def get_post_by_id(post_id):
    """Get a specific post by ID"""
    print(f"\nFetching post {post_id}...")

    response = requests.get(f"{SERVER_URL}/api/posts/{post_id}")

    if response.status_code == 200:
        result = response.json()
        post = result['post']
        print(f"\n✓ Post found:")
        print(f"  Title: {post['title']}")
        print(f"  Summary: {post['summary']}")
        print(f"  Body:\n{post['body']}")
        print(f"  Created: {post['created_at']}")
        print(f"  Timezone: {post['timezone']}")
        if post.get('location_tag'):
            print(f"  Location: {post['location_tag']}")
        if post.get('image_url'):
            print(f"  Image: {post['image_url']}")
        print(f"  AI Generated: {post['ai_generated']}")
    else:
        print(f"\n✗ Failed to get post")
        print(f"  Status: {response.status_code}")
        print(f"  Response: {response.text}")

if __name__ == '__main__':
    # Create a test post
    post_id = create_test_post()

    if post_id:
        # Get the post we just created
        get_post_by_id(post_id)

        # Get all recent posts
        get_recent_posts()
