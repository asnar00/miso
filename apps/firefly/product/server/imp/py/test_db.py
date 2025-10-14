"""
Test script to verify database connection and basic operations.
"""

from db import db
import sys

def test_database():
    """Test database connection and basic CRUD operations"""

    print("🔧 Testing database connection...")

    try:
        # Initialize database connection
        db.initialize_pool()
        print("✅ Database connection successful!")

        # Test 1: Create a user
        print("\n📝 Test 1: Creating a user...")
        user_id = db.create_user("test@example.com")
        if user_id:
            print(f"✅ User created with ID: {user_id}")
        else:
            print("❌ Failed to create user")
            return False

        # Test 2: Get user by email
        print("\n📝 Test 2: Getting user by email...")
        user = db.get_user_by_email("test@example.com")
        if user:
            print(f"✅ User found: {user['email']}, ID: {user['id']}")
        else:
            print("❌ User not found")
            return False

        # Test 3: Create a post
        print("\n📝 Test 3: Creating a post...")
        post_id = db.create_post(
            user_id=user_id,
            title="Test Post",
            summary="This is a test post",
            body="This is the body of the test post with some more content.",
            timezone="UTC",
            embedding=[0.1] * 768  # Dummy embedding vector
        )
        if post_id:
            print(f"✅ Post created with ID: {post_id}")
        else:
            print("❌ Failed to create post")
            return False

        # Test 4: Get post by ID
        print("\n📝 Test 4: Getting post by ID...")
        post = db.get_post_by_id(post_id)
        if post:
            print(f"✅ Post found: {post['title']}")
        else:
            print("❌ Post not found")
            return False

        # Test 5: Get posts by user
        print("\n📝 Test 5: Getting posts by user...")
        posts = db.get_posts_by_user(user_id)
        if posts and len(posts) > 0:
            print(f"✅ Found {len(posts)} post(s) for user")
        else:
            print("❌ No posts found for user")
            return False

        # Test 6: Vector similarity search
        print("\n📝 Test 6: Testing vector similarity search...")
        query_embedding = [0.1] * 768  # Same as post embedding for testing
        results = db.search_posts_by_embedding(query_embedding, limit=10)
        if len(results) > 0:
            print(f"✅ Found {len(results)} similar post(s)")
            print(f"   Top result similarity: {results[0]['similarity']:.4f}")
        else:
            print("⚠️  No results found (this might be okay if threshold is too high)")

        print("\n✅ All tests passed successfully!")

        # Cleanup
        print("\n🧹 Cleaning up test data...")
        conn = db.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM users WHERE email = 'test@example.com'")
                conn.commit()
            print("✅ Cleanup completed")
        finally:
            db.return_connection(conn)

        return True

    except Exception as e:
        print(f"\n❌ Error during testing: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        db.close_all_connections()

if __name__ == "__main__":
    success = test_database()
    sys.exit(0 if success else 1)
