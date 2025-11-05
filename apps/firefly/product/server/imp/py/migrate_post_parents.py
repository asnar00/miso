#!/usr/bin/env python3
"""
Database migration script to retroactively set parent_id for existing posts.

This script updates all posts that have parent_id = NULL to have parent_id
set to the user's profile post ID (the post with parent_id = -1 for that user).

Posts with parent_id = -1 (profile posts) are left unchanged.
Posts that already have a parent_id are left unchanged.
"""

import sys
from db import Database

def migrate_post_parents():
    """
    Update all posts without a parent to be children of their user's profile post.
    """
    db = Database()

    try:
        conn = db.get_connection()
        with conn.cursor() as cur:
            # Find all posts that need migration (parent_id is NULL)
            # Exclude profile posts themselves (parent_id = -1)
            cur.execute("""
                SELECT id, user_id, title
                FROM posts
                WHERE parent_id IS NULL
                ORDER BY user_id, created_at
            """)

            posts_to_migrate = cur.fetchall()

            if not posts_to_migrate:
                print("No posts need migration. All posts already have a parent_id.")
                return

            print(f"Found {len(posts_to_migrate)} posts that need parent_id set.\n")

            # Group posts by user
            posts_by_user = {}
            for post_id, user_id, title in posts_to_migrate:
                if user_id not in posts_by_user:
                    posts_by_user[user_id] = []
                posts_by_user[user_id].append((post_id, title))

            # Process each user's posts
            total_updated = 0
            total_skipped = 0

            for user_id, posts in posts_by_user.items():
                # Get user's profile post
                cur.execute("""
                    SELECT id, title
                    FROM posts
                    WHERE user_id = %s AND parent_id = -1
                    LIMIT 1
                """, (user_id,))

                profile = cur.fetchone()

                if not profile:
                    print(f"WARNING: User {user_id} has no profile post. Skipping {len(posts)} posts.")
                    total_skipped += len(posts)
                    for post_id, title in posts:
                        print(f"  - Skipped post {post_id}: {title[:50]}")
                    print()
                    continue

                profile_id, profile_title = profile

                print(f"User {user_id} (profile: '{profile_title[:50]}')")
                print(f"  Setting parent_id = {profile_id} for {len(posts)} posts:")

                # Update all posts for this user
                for post_id, title in posts:
                    cur.execute("""
                        UPDATE posts
                        SET parent_id = %s
                        WHERE id = %s
                    """, (profile_id, post_id))

                    print(f"    - Post {post_id}: {title[:50]}")
                    total_updated += 1

                print()

            # Commit all changes
            conn.commit()

            print("=" * 60)
            print(f"Migration complete!")
            print(f"  Total posts updated: {total_updated}")
            print(f"  Total posts skipped: {total_skipped}")
            print("=" * 60)

    except Exception as e:
        print(f"ERROR: Migration failed: {e}", file=sys.stderr)
        conn.rollback()
        return False

    finally:
        db.return_connection(conn)

    return True

if __name__ == "__main__":
    print("Starting database migration: Set parent_id for existing posts")
    print("=" * 60)
    print()

    success = migrate_post_parents()

    if success:
        sys.exit(0)
    else:
        sys.exit(1)
