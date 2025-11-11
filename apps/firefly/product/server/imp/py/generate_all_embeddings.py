#!/usr/bin/env python3
"""
Generate embeddings for all existing posts in the database.
One-time migration script to create embedding files for posts that don't have them yet.
"""

import sys
from db import db
import embeddings

def main():
    """Generate embeddings for all posts in the database"""
    print("[GENERATE_EMBEDDINGS] Starting embedding generation for all posts...")

    # Get all posts from database
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title, summary, body FROM posts ORDER BY id")
            posts = cur.fetchall()

            print(f"[GENERATE_EMBEDDINGS] Found {len(posts)} posts")

            success_count = 0
            error_count = 0

            for post in posts:
                post_id, title, summary, body = post

                # Check if embeddings already exist
                existing = embeddings.load_embeddings(post_id)
                if existing is not None:
                    print(f"[GENERATE_EMBEDDINGS] Post {post_id}: embeddings already exist, skipping")
                    success_count += 1
                    continue

                # Generate embeddings
                print(f"[GENERATE_EMBEDDINGS] Post {post_id}: generating embeddings...")
                result = embeddings.generate_embeddings(post_id, title, summary, body)

                if result:
                    success_count += 1
                else:
                    error_count += 1
                    print(f"[GENERATE_EMBEDDINGS] Post {post_id}: FAILED")

            print(f"\n[GENERATE_EMBEDDINGS] Complete!")
            print(f"  Success: {success_count}")
            print(f"  Errors: {error_count}")
            print(f"  Total: {len(posts)}")

            return error_count == 0

    except Exception as e:
        print(f"[GENERATE_EMBEDDINGS] Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        db.return_connection(conn)

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
