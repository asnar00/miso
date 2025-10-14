#!/usr/bin/env python3
"""
List all users in the Firefly database.
"""

import sys
import os

# Add server directory to path to import db module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../../../../product/server/imp/py'))

from db import db

def list_users():
    """Fetch and display all users"""

    try:
        # Initialize database connection
        db.initialize_pool()

        # Get connection
        conn = db.get_connection()

        try:
            with conn.cursor() as cur:
                # Fetch all users
                cur.execute("""
                    SELECT id, email, created_at,
                           array_length(device_ids, 1) as device_count
                    FROM users
                    ORDER BY created_at DESC
                """)

                users = cur.fetchall()

                if not users:
                    print("No users found in database.")
                    return

                # Print header
                print(f"\n{'ID':<8} {'Email':<40} {'Created':<26} {'Devices':<8}")
                print("=" * 82)

                # Print each user
                for user in users:
                    user_id, email, created_at, device_count = user
                    device_count_str = str(device_count) if device_count else "0"
                    print(f"{user_id:<8} {email:<40} {created_at.strftime('%Y-%m-%d %H:%M:%S %Z'):<26} {device_count_str:<8}")

                print(f"\nTotal users: {len(users)}\n")

        finally:
            db.return_connection(conn)

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        db.close_all_connections()

if __name__ == "__main__":
    list_users()
