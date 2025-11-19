#!/usr/bin/env python3
"""
Regenerate embeddings for all posts in the database.
Use this when switching embedding models.
"""

import sys
from db import db
import embeddings

def regenerate_all_embeddings():
    """Regenerate embeddings for all posts"""
    print("[REGEN] Starting embedding regeneration...")

    # Get all posts
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title, summary, body FROM posts ORDER BY id")
            posts = cur.fetchall()

        print(f"[REGEN] Found {len(posts)} posts to process")

        success_count = 0
        fail_count = 0

        for post in posts:
            post_id, title, summary, body = post
            print(f"\n[REGEN] Processing post {post_id}: {title}")

            # Generate embeddings
            if embeddings.generate_embeddings(post_id, title, summary or "", body or ""):
                success_count += 1
                print(f"[REGEN] ✓ Post {post_id} completed")
            else:
                fail_count += 1
                print(f"[REGEN] ✗ Post {post_id} failed")

        print(f"\n[REGEN] Complete!")
        print(f"[REGEN] Success: {success_count}")
        print(f"[REGEN] Failed: {fail_count}")

    except Exception as e:
        print(f"[REGEN] Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.return_connection(conn)

if __name__ == '__main__':
    # Initialize database
    db.initialize_pool()
    regenerate_all_embeddings()
