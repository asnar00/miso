#!/usr/bin/env python3
"""
Fix the parent_id foreign key constraint to allow -1 for profile posts.
"""

import psycopg2
import sys

def fix_constraint():
    try:
        # Connect to database
        conn = psycopg2.connect(
            host="localhost",
            database="firefly",
            user="postgres",
            password=""
        )

        print("[FIX] Connected to database", file=sys.stderr, flush=True)

        with conn.cursor() as cur:
            # Drop the existing foreign key constraint
            print("[FIX] Dropping existing foreign key constraint...", file=sys.stderr, flush=True)
            cur.execute("""
                ALTER TABLE posts
                DROP CONSTRAINT IF EXISTS posts_parent_id_fkey
            """)

            # Add a new constraint that allows -1 or valid post IDs
            print("[FIX] Adding new constraint allowing -1...", file=sys.stderr, flush=True)
            cur.execute("""
                ALTER TABLE posts
                ADD CONSTRAINT posts_parent_id_fkey
                FOREIGN KEY (parent_id)
                REFERENCES posts(id)
                ON DELETE CASCADE
                NOT VALID
            """)

            # Add a check constraint to allow -1 specifically
            print("[FIX] Adding check constraint for -1...", file=sys.stderr, flush=True)
            cur.execute("""
                ALTER TABLE posts
                ADD CONSTRAINT posts_parent_id_check
                CHECK (parent_id IS NULL OR parent_id = -1 OR parent_id > 0)
            """)

            conn.commit()
            print("[FIX] Successfully updated constraints!", file=sys.stderr, flush=True)

    except Exception as e:
        print(f"[FIX] Error: {e}", file=sys.stderr, flush=True)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    fix_constraint()
