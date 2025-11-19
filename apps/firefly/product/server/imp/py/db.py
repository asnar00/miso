"""
Database module for Firefly server.
Handles PostgreSQL operations with pgvector for semantic search.
"""

import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from typing import Optional, List, Dict, Any
import os
from datetime import datetime
import sys
import embeddings
import subprocess
import time
import threading

class Database:
    """Database connection and operations manager"""

    def __init__(self, db_config: Optional[Dict[str, str]] = None):
        """
        Initialize database connection pool.

        Args:
            db_config: Dict with keys: host, port, database, user, password
                      If None, reads from environment variables
        """
        if db_config is None:
            db_config = {
                'host': os.getenv('DB_HOST', 'localhost'),
                'port': os.getenv('DB_PORT', '5432'),
                'database': os.getenv('DB_NAME', 'firefly'),
                'user': os.getenv('DB_USER', 'firefly_user'),
                'password': os.getenv('DB_PASSWORD', 'firefly_pass')
            }

        self.db_config = db_config
        self.connection_pool = None
        self._pool_lock = threading.Lock()  # Thread safety for pool initialization

    def check_postgresql_running(self):
        """Check if PostgreSQL is running"""
        try:
            result = subprocess.run([
                '/opt/homebrew/opt/postgresql@16/bin/pg_ctl',
                '-D', '/opt/homebrew/var/postgresql@16',
                'status'
            ], capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except Exception as e:
            print(f"[DB] Error checking PostgreSQL status: {e}")
            return False

    def restart_postgresql(self):
        """Restart PostgreSQL if it's not responding"""
        print("[DB] PostgreSQL not responding, attempting to restart...")
        try:
            # Start PostgreSQL
            result = subprocess.run([
                '/opt/homebrew/opt/postgresql@16/bin/pg_ctl',
                '-D', '/opt/homebrew/var/postgresql@16',
                '-l', '/opt/homebrew/var/log/postgresql@16.log',
                'start'
            ], capture_output=True, text=True, timeout=10)

            if result.returncode == 0:
                print("[DB] PostgreSQL started successfully")
                time.sleep(2)  # Wait for PostgreSQL to be ready
                return True
            else:
                print(f"[DB] Failed to start PostgreSQL: {result.stderr}")
                return False
        except Exception as e:
            print(f"[DB] Error restarting PostgreSQL: {e}")
            return False

    def initialize_pool(self, minconn=1, maxconn=10, retry_with_restart=True):
        """Initialize the connection pool with thread safety"""
        with self._pool_lock:
            # Check again inside the lock to avoid double initialization
            if self.connection_pool is not None:
                print("[DB] Pool already initialized, skipping")
                return

            try:
                self.connection_pool = psycopg2.pool.SimpleConnectionPool(
                    minconn, maxconn, **self.db_config
                )
                print(f"Database connection pool initialized: {self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}")
            except Exception as e:
                print(f"Error initializing database pool: {e}")

                # Try to restart PostgreSQL and retry
                if retry_with_restart and "Connection refused" in str(e):
                    print("[DB] Attempting to restart PostgreSQL and retry...")
                    if self.restart_postgresql():
                        try:
                            self.connection_pool = psycopg2.pool.SimpleConnectionPool(
                                minconn, maxconn, **self.db_config
                            )
                            print(f"[DB] Database connection pool initialized after restart")
                            return
                        except Exception as e2:
                            print(f"[DB] Failed to initialize pool after restart: {e2}")

                raise

    def get_connection(self):
        """Get a connection from the pool"""
        if self.connection_pool is None:
            self.initialize_pool()

        try:
            return self.connection_pool.getconn()
        except Exception as e:
            # If we can't get a connection, try reinitializing the pool
            print(f"[DB] Error getting connection, reinitializing pool: {e}")
            self.connection_pool = None
            self.initialize_pool()
            return self.connection_pool.getconn()

    def return_connection(self, conn):
        """Return a connection to the pool"""
        if self.connection_pool and conn:
            try:
                self.connection_pool.putconn(conn)
            except Exception as e:
                # If we can't return the connection, it's corrupted - close it and reset pool
                print(f"[DB] Error returning connection to pool: {e}")
                try:
                    conn.close()
                except:
                    pass
                # Reset the pool to recover from corruption
                print("[DB] Resetting connection pool due to corruption")
                self.connection_pool.closeall()
                self.connection_pool = None

    def close_all_connections(self):
        """Close all connections in the pool"""
        if self.connection_pool:
            self.connection_pool.closeall()

    def migrate_add_last_activity(self):
        """Add last_activity column to users table if it doesn't exist"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Add column if it doesn't exist
                cur.execute("""
                    ALTER TABLE users
                    ADD COLUMN IF NOT EXISTS last_activity TIMESTAMP
                """)

                # Initialize with most recent post timestamp for existing users
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

                conn.commit()
                print("Migration: last_activity column added and initialized")
        except Exception as e:
            conn.rollback()
            print(f"Migration error: {e}")
        finally:
            self.return_connection(conn)

    # User operations

    def create_user(self, email: str) -> Optional[int]:
        """
        Create a new user.

        Args:
            email: User's email address

        Returns:
            User ID if successful, None otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO users (email) VALUES (%s) RETURNING id",
                    (email,)
                )
                user_id = cur.fetchone()[0]
                conn.commit()
                return user_id
        except psycopg2.IntegrityError:
            conn.rollback()
            print(f"User with email {email} already exists")
            return None
        except Exception as e:
            conn.rollback()
            print(f"Error creating user: {e}")
            return None
        finally:
            self.return_connection(conn)

    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email address"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT id, email, created_at, device_ids FROM users WHERE email = %s",
                    (email,)
                )
                return cur.fetchone()
        except Exception as e:
            print(f"Error getting user: {e}")
            return None
        finally:
            self.return_connection(conn)

    def get_user_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT id, email, created_at, device_ids FROM users WHERE id = %s",
                    (user_id,)
                )
                return cur.fetchone()
        except Exception as e:
            print(f"Error getting user: {e}")
            return None
        finally:
            self.return_connection(conn)

    def add_device_to_user(self, user_id: int, device_id: str) -> bool:
        """Add a device ID to a user's device list"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE users SET device_ids = array_append(device_ids, %s) WHERE id = %s AND NOT (%s = ANY(device_ids))",
                    (device_id, user_id, device_id)
                )
                conn.commit()
                return True
        except Exception as e:
            conn.rollback()
            print(f"Error adding device to user: {e}")
            return False
        finally:
            self.return_connection(conn)

    # Post operations

    def create_post(
        self,
        user_id: int,
        title: str,
        summary: str,
        body: str,
        timezone: str,
        parent_id: Optional[int] = None,
        image_url: Optional[str] = None,
        location_tag: Optional[str] = None,
        ai_generated: bool = False,
        embedding: Optional[List[float]] = None,
        template_name: str = 'post'
    ) -> Optional[int]:
        """
        Create a new post.

        Args:
            user_id: ID of the user creating the post
            title: Post title
            summary: One-line summary
            body: Post body text
            timezone: User's timezone
            parent_id: ID of parent post (if this is a child post)
            image_url: URL to post image
            location_tag: Optional location tag
            ai_generated: Whether this post was AI-generated
            embedding: Vector embedding for semantic search
            template_name: Name of template to use (defaults to 'post')

        Returns:
            Post ID if successful, None otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO posts
                    (user_id, parent_id, title, summary, body, image_url, timezone, location_tag, ai_generated, embedding, template_name)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                    """,
                    (user_id, parent_id, title, summary, body, image_url, timezone, location_tag, ai_generated, embedding, template_name)
                )
                post_id = cur.fetchone()[0]

                # Update user's last_activity timestamp
                cur.execute(
                    "UPDATE users SET last_activity = NOW() WHERE id = %s",
                    (user_id,)
                )

                conn.commit()

                # Generate embeddings for the new post
                embeddings.generate_embeddings(post_id, title, summary, body)

                return post_id
        except Exception as e:
            conn.rollback()
            print(f"Error creating post: {e}", file=sys.stderr, flush=True)
            import traceback
            traceback.print_exc(file=sys.stderr)
            return None
        finally:
            self.return_connection(conn)

    def update_post(
        self,
        post_id: int,
        title: str,
        summary: str,
        body: str,
        image_url: Optional[str] = None
    ) -> bool:
        """
        Update an existing post.

        Args:
            post_id: ID of the post to update
            title: New post title
            summary: New one-line summary
            body: New post body text
            image_url: New image URL (if changed)

        Returns:
            True if successful, False otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE posts
                    SET title = %s, summary = %s, body = %s, image_url = %s
                    WHERE id = %s
                    """,
                    (title, summary, body, image_url, post_id)
                )
                conn.commit()

                # Regenerate embeddings for the updated post
                embeddings.generate_embeddings(post_id, title, summary, body)

                return True
        except Exception as e:
            conn.rollback()
            print(f"Error updating post: {e}")
            return False
        finally:
            self.return_connection(conn)

    def get_post_by_id(self, post_id: int) -> Optional[Dict[str, Any]]:
        """Get a post by ID"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           (SELECT COUNT(*) FROM posts WHERE parent_id = p.id) as child_count
                    FROM posts p
                    LEFT JOIN users u ON p.user_id = u.id
                    LEFT JOIN templates t ON p.template_name = t.name
                    WHERE p.id = %s
                    """,
                    (post_id,)
                )
                return cur.fetchone()
        except Exception as e:
            print(f"Error getting post: {e}")
            return None
        finally:
            self.return_connection(conn)

    def get_posts_by_user(self, user_id: int, limit: int = 100) -> List[Dict[str, Any]]:
        """Get all posts by a user"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body
                    FROM posts p
                    LEFT JOIN templates t ON p.template_name = t.name
                    WHERE p.user_id = %s
                    ORDER BY p.created_at DESC
                    LIMIT %s
                    """,
                    (user_id, limit)
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting user posts: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_child_posts(self, parent_id: int) -> List[Dict[str, Any]]:
        """Get all child posts of a parent post with author names and child counts"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           COUNT(children.id) as child_count
                    FROM posts p
                    LEFT JOIN users u ON p.user_id = u.id
                    LEFT JOIN templates t ON p.template_name = t.name
                    LEFT JOIN posts children ON children.parent_id = p.id
                    WHERE p.parent_id = %s
                    GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body
                    ORDER BY p.created_at DESC
                    """,
                    (parent_id,)
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting child posts: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_user_profile(self, user_id: int) -> Optional[Dict[str, Any]]:
        """
        Get a user's profile post (post with parent_id = -1).
        Profile posts are distinguished by having parent_id = -1 (a special marker).

        Args:
            user_id: The user's ID

        Returns:
            Profile post dict if found, None otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT
                        p.id, p.user_id, p.parent_id, p.title, p.summary, p.body,
                        p.image_url, p.created_at, p.timezone, p.location_tag, p.ai_generated,
                        p.template_name,
                        t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                        p.title as author_name,
                        u.email as author_email,
                        (SELECT COUNT(*) FROM posts WHERE parent_id = p.id) as child_count
                    FROM posts p
                    LEFT JOIN users u ON p.user_id = u.id
                    LEFT JOIN templates t ON p.template_name = t.name
                    WHERE p.user_id = %s AND p.template_name = 'profile'
                    LIMIT 1
                """, (user_id,))
                result = cur.fetchone()

                if result:
                    return dict(result)
                return None
        except Exception as e:
            print(f"Error getting user profile: {e}")
            return None
        finally:
            self.return_connection(conn)

    def create_profile_post(
        self,
        user_id: int,
        title: str,
        summary: str,
        body: str,
        timezone: str = 'UTC',
        image_url: Optional[str] = None
    ) -> Optional[int]:
        """
        Create a profile post for a user (with parent_id = -1).
        Profile posts use -1 as a special marker to distinguish them from regular posts.

        Args:
            user_id: User creating the profile
            title: User's name
            summary: User's profession/mission
            body: About text
            timezone: User's timezone
            image_url: Optional profile photo URL

        Returns:
            Post ID if successful, None otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                print(f"[DB] Executing INSERT for profile post: user_id={user_id}, title='{title}', summary='{summary}'", file=sys.stderr, flush=True)
                cur.execute("""
                    INSERT INTO posts (user_id, parent_id, title, summary, body, timezone, image_url, ai_generated)
                    VALUES (%s, -1, %s, %s, %s, %s, %s, false)
                    RETURNING id
                """, (user_id, title, summary, body, timezone, image_url))
                post_id = cur.fetchone()[0]
                conn.commit()
                print(f"[DB] Created profile post {post_id} for user {user_id}", file=sys.stderr, flush=True)
                return post_id
        except Exception as e:
            conn.rollback()
            print(f"[DB] Error creating profile post: {e}", file=sys.stderr, flush=True)
            import traceback
            traceback.print_exc(file=sys.stderr)
            return None
        finally:
            self.return_connection(conn)

    def update_post(
        self,
        post_id: int,
        title: Optional[str] = None,
        summary: Optional[str] = None,
        body: Optional[str] = None,
        image_url: Optional[str] = None
    ) -> bool:
        """
        Update an existing post.

        Args:
            post_id: ID of post to update
            title: New title (optional)
            summary: New summary (optional)
            body: New body (optional)
            image_url: New image URL (optional)

        Returns:
            True if successful, False otherwise
        """
        conn = self.get_connection()
        try:
            # Build dynamic update query
            updates = []
            params = []

            if title is not None:
                updates.append("title = %s")
                params.append(title)

            if summary is not None:
                updates.append("summary = %s")
                params.append(summary)

            if body is not None:
                updates.append("body = %s")
                params.append(body)

            if image_url is not None:
                updates.append("image_url = %s")
                params.append(image_url)

            if not updates:
                print("No fields to update")
                return False

            params.append(post_id)
            query = f"UPDATE posts SET {', '.join(updates)} WHERE id = %s"

            with conn.cursor() as cur:
                cur.execute(query, params)
                conn.commit()
                print(f"Updated post {post_id}")
                return True
        except Exception as e:
            conn.rollback()
            print(f"Error updating post: {e}")
            return False
        finally:
            self.return_connection(conn)

    def search_posts_by_embedding(
        self,
        query_embedding: List[float],
        limit: int = 10,
        threshold: float = 0.7
    ) -> List[Dict[str, Any]]:
        """
        Search posts using vector similarity.

        Args:
            query_embedding: The query vector
            limit: Maximum number of results
            threshold: Minimum similarity threshold (0-1, where 1 is most similar)

        Returns:
            List of posts with similarity scores
        """
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT
                        p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                        p.created_at, p.timezone, p.location_tag, p.ai_generated,
                        p.template_name,
                        t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                        1 - (p.embedding <=> %s::vector) as similarity
                    FROM posts p
                    LEFT JOIN templates t ON p.template_name = t.name
                    WHERE p.embedding IS NOT NULL
                    AND 1 - (p.embedding <=> %s::vector) >= %s
                    ORDER BY p.embedding <=> %s::vector
                    LIMIT %s
                    """,
                    (query_embedding, query_embedding, threshold, query_embedding, limit)
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error searching posts: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_recent_posts(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get most recent posts with child counts"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           COUNT(children.id) as child_count
                    FROM posts p
                    LEFT JOIN users u ON p.user_id = u.id
                    LEFT JOIN templates t ON p.template_name = t.name
                    LEFT JOIN posts children ON children.parent_id = p.id
                    GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body
                    ORDER BY p.created_at DESC
                    LIMIT %s
                    """,
                    (limit,)
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting recent posts: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_recent_users(self) -> List[Dict[str, Any]]:
        """Get users ordered by most recent activity, with their profile posts (parent_id = -1)"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           COUNT(children.id) as child_count
                    FROM users u
                    JOIN posts p ON p.user_id = u.id AND p.parent_id = -1
                    LEFT JOIN templates t ON p.template_name = t.name
                    LEFT JOIN posts children ON children.parent_id = p.id
                    GROUP BY p.id, u.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body
                    ORDER BY u.last_activity DESC
                    """
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting recent users: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_recent_tagged_posts(self, tags: List[str] = None, user_id: Optional[int] = None, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent posts filtered by template tags and optionally by user"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Build query
                query = """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           COUNT(children.id) as child_count
                    FROM posts p
                    LEFT JOIN users u ON p.user_id = u.id
                    LEFT JOIN templates t ON p.template_name = t.name
                    LEFT JOIN posts children ON children.parent_id = p.id
                """

                conditions = []
                params = []

                # Filter by tags if provided
                if tags:
                    placeholders = ','.join(['%s'] * len(tags))
                    conditions.append(f"p.template_name IN ({placeholders})")
                    params.extend(tags)

                # Filter by user if provided
                if user_id is not None:
                    conditions.append("p.user_id = %s")
                    params.append(user_id)

                # Add WHERE clause if conditions exist
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)

                # Group by
                query += " GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name"

                # Sort order - if profile tag, sort by user activity, otherwise by post date
                if tags and "profile" in tags:
                    query += """
                        ORDER BY (
                            SELECT MAX(created_at)
                            FROM posts
                            WHERE user_id = p.user_id
                        ) DESC
                    """
                else:
                    query += " ORDER BY p.created_at DESC"

                # Add limit
                query += " LIMIT %s"
                params.append(limit)

                cur.execute(query, params)
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting recent tagged posts: {e}")
            return []
        finally:
            self.return_connection(conn)

    def set_post_parent(self, post_id: int, parent_id: Optional[int]) -> bool:
        """
        Set or update the parent of a post.

        Args:
            post_id: ID of the post to update
            parent_id: ID of the new parent post (or None to make it a root post)

        Returns:
            True if successful, False otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Verify both posts exist if parent_id is provided
                if parent_id is not None:
                    cur.execute("SELECT id FROM posts WHERE id = %s", (parent_id,))
                    if cur.fetchone() is None:
                        print(f"Parent post {parent_id} does not exist")
                        return False

                cur.execute("SELECT id FROM posts WHERE id = %s", (post_id,))
                if cur.fetchone() is None:
                    print(f"Post {post_id} does not exist")
                    return False

                # Update the parent_id
                cur.execute(
                    "UPDATE posts SET parent_id = %s WHERE id = %s",
                    (parent_id, post_id)
                )
                conn.commit()
                return True
        except Exception as e:
            conn.rollback()
            print(f"Error setting post parent: {e}")
            return False
        finally:
            self.return_connection(conn)

# Global database instance
db = Database()
