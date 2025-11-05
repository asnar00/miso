"""
Grant permissions on templates table to firefly_user
"""

import psycopg2

def grant_permissions():
    """Grant SELECT permission on templates table"""

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
            print("Granting SELECT permission on templates table to firefly_user...")
            cur.execute("""
                GRANT SELECT ON templates TO firefly_user
            """)

            conn.commit()
            print("Successfully granted permissions!")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    grant_permissions()
