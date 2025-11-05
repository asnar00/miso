#!/usr/bin/env python3
"""
Migration script to add and initialize last_activity column.
Run this with postgres superuser credentials.
"""

import psycopg2
import sys

# Connect as postgres superuser
try:
    conn = psycopg2.connect(
        host="localhost",
        port="5432",
        database="firefly",
        user="microserver"  # Superuser
    )
    cur = conn.cursor()

    print("Adding last_activity column to users table...")
    cur.execute("""
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS last_activity TIMESTAMP
    """)

    print("Initializing last_activity for existing users...")
    cur.execute("""
        UPDATE users u
        SET last_activity = (
            SELECT MAX(p.created_at)
            FROM posts p
            WHERE p.user_id = u.id
        )
        WHERE EXISTS (
            SELECT 1 FROM posts p WHERE p.user_id = u.id
        ) AND last_activity IS NULL
    """)

    rows_updated = cur.rowcount
    conn.commit()

    print(f"Successfully updated {rows_updated} users")
    print()
    print("Checking results...")

    cur.execute("""
        SELECT id, name, email, last_activity
        FROM users
        ORDER BY last_activity DESC NULLS LAST
    """)

    for user_id, name, email, last_activity in cur.fetchall():
        name_str = name if name else "(no name)"
        activity_str = str(last_activity) if last_activity else "(no posts yet)"
        print(f"{user_id:2d}. {name_str:20s} - {activity_str}")

    cur.close()
    conn.close()
    print("\nMigration complete!")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
