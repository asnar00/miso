#!/usr/bin/env python3
"""
Clean up image links from post bodies in the database.
Removes ![caption](filename) markdown image syntax and leading whitespace.
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import re
import os
import sys

def connect_to_db():
    """Connect to the database"""
    db_config = {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': os.getenv('DB_PORT', '5432'),
        'database': os.getenv('DB_NAME', 'firefly'),
        'user': os.getenv('DB_USER', 'firefly_user'),
        'password': os.getenv('DB_PASSWORD', 'firefly_pass')
    }

    conn = psycopg2.connect(**db_config)
    print(f"Connected to database: {db_config['host']}:{db_config['port']}/{db_config['database']}")
    return conn

def cleanup_image_links(body_text):
    """
    Remove image links from markdown text and strip leading whitespace.

    Args:
        body_text: Original markdown text

    Returns:
        Cleaned text with image links removed and leading whitespace stripped
    """
    # Remove markdown image syntax: ![caption](filename)
    # Pattern matches ![anything](anything)
    pattern = r'!\[.*?\]\(.*?\)'
    cleaned = re.sub(pattern, '', body_text)

    # Strip leading whitespace (spaces, tabs, newlines)
    cleaned = cleaned.lstrip()

    return cleaned

def main():
    """Main function to clean up posts"""
    # Check for --yes flag
    auto_confirm = '--yes' in sys.argv or '-y' in sys.argv

    conn = connect_to_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Find all posts with image links in their body
        print("\nSearching for posts with image links...")
        cursor.execute("""
            SELECT id, title, body
            FROM posts
            WHERE body LIKE '%![%](%'
            ORDER BY id
        """)

        posts = cursor.fetchall()
        print(f"Found {len(posts)} posts with image links\n")

        if len(posts) == 0:
            print("No posts to clean up!")
            return

        # Show what will be changed
        print("Posts to be cleaned:")
        print("-" * 80)
        for post in posts:
            print(f"\nPost ID: {post['id']}")
            print(f"Title: {post['title']}")
            print(f"\nOriginal body:")
            print(post['body'][:200] + "..." if len(post['body']) > 200 else post['body'])

            cleaned = cleanup_image_links(post['body'])
            print(f"\nCleaned body:")
            print(cleaned[:200] + "..." if len(cleaned) > 200 else cleaned)
            print("-" * 80)

        # Ask for confirmation
        if auto_confirm:
            print(f"\nAuto-confirming update of {len(posts)} posts (--yes flag)")
        else:
            response = input(f"\nUpdate {len(posts)} posts? (yes/no): ")
            if response.lower() != 'yes':
                print("Cancelled.")
                return

        # Update each post
        print("\nUpdating posts...")
        updated_count = 0
        for post in posts:
            cleaned_body = cleanup_image_links(post['body'])

            cursor.execute("""
                UPDATE posts
                SET body = %s
                WHERE id = %s
            """, (cleaned_body, post['id']))

            updated_count += 1
            print(f"Updated post {post['id']}: {post['title']}")

        # Commit changes
        conn.commit()
        print(f"\nSuccessfully updated {updated_count} posts!")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    main()
