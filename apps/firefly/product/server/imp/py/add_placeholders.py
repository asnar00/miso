"""
Add placeholder columns to posts table
"""

import psycopg2
import os

def add_placeholder_columns():
    """Add title_placeholder, summary_placeholder, body_placeholder columns to posts table"""

    db_config = {
        'host': 'localhost',
        'port': '5432',
        'database': 'firefly',
        'user': 'microserver',
        'password': ''
    }

    conn = psycopg2.connect(**db_config)

    try:
        with conn.cursor() as cur:
            # Add placeholder columns
            print("Adding placeholder columns to posts table...")
            cur.execute("""
                ALTER TABLE posts
                ADD COLUMN IF NOT EXISTS title_placeholder TEXT,
                ADD COLUMN IF NOT EXISTS summary_placeholder TEXT,
                ADD COLUMN IF NOT EXISTS body_placeholder TEXT
            """)

            conn.commit()
            print("Successfully added placeholder columns")

            # Update the asnaroo post with custom placeholders
            print("Setting custom placeholders for 'asnaroo' post...")
            cur.execute("""
                UPDATE posts
                SET title_placeholder = 'name',
                    summary_placeholder = 'mission',
                    body_placeholder = 'personal statement'
                WHERE title = 'asnaroo'
            """)

            conn.commit()
            print("Successfully set custom placeholders for 'asnaroo' post")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    add_placeholder_columns()
