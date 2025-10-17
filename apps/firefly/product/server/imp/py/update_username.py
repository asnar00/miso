from db import db

# Initialize database connection
db.initialize_pool()

conn = db.get_connection()
try:
    with conn.cursor() as cur:
        # Try to check if username column exists
        cur.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='users' AND column_name='username'
        """)
        
        column_exists = cur.fetchone() is not None
        print(f"Username column exists: {column_exists}")
        
        if column_exists:
            # Update test@example.com user to have username 'asnaroo'
            cur.execute("""
                UPDATE users 
                SET username = 'asnaroo' 
                WHERE email = 'test@example.com'
            """)
            conn.commit()
            print("Successfully updated test@example.com username to 'asnaroo'")
            
            # Verify the change
            cur.execute("SELECT id, email, username FROM users WHERE email = 'test@example.com'")
            result = cur.fetchone()
            if result:
                print(f"User: id={result[0]}, email={result[1]}, username={result[2]}")
            else:
                print("User test@example.com not found")
        else:
            print("Error: username column does not exist. Please add it to the users table first.")
        
except Exception as e:
    conn.rollback()
    print(f"Error: {e}")
finally:
    db.return_connection(conn)
    db.close_all_connections()
