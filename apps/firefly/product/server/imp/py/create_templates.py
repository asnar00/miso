"""
Create templates table and migrate placeholder data from posts table
"""

import psycopg2

def create_templates_table():
    """Create templates table and migrate existing placeholder data"""

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
            # Create templates table
            print("Creating templates table...")
            cur.execute("""
                CREATE TABLE IF NOT EXISTS templates (
                    name TEXT PRIMARY KEY,
                    placeholder_title TEXT NOT NULL,
                    placeholder_summary TEXT NOT NULL,
                    placeholder_body TEXT NOT NULL
                )
            """)

            # Insert default templates
            print("Inserting default templates...")
            cur.execute("""
                INSERT INTO templates (name, placeholder_title, placeholder_summary, placeholder_body)
                VALUES
                    ('post', 'Title', 'Summary', 'Body'),
                    ('profile', 'name', 'mission', 'personal statement')
                ON CONFLICT (name) DO NOTHING
            """)

            # Add template_name column to posts table
            print("Adding template_name column to posts table...")
            cur.execute("""
                ALTER TABLE posts
                ADD COLUMN IF NOT EXISTS template_name TEXT DEFAULT 'post'
            """)

            # Update the asnaroo post to use profile template
            print("Setting asnaroo post to use profile template...")
            cur.execute("""
                UPDATE posts
                SET template_name = 'profile'
                WHERE title = 'asnaroo'
            """)

            # Drop old placeholder columns from posts table
            print("Dropping old placeholder columns from posts table...")
            cur.execute("""
                ALTER TABLE posts
                DROP COLUMN IF EXISTS title_placeholder,
                DROP COLUMN IF EXISTS summary_placeholder,
                DROP COLUMN IF EXISTS body_placeholder
            """)

            conn.commit()
            print("Successfully created templates system!")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    create_templates_table()
