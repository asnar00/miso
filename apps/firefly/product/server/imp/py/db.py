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

    def migrate_add_clip_offsets(self):
        """Add clip_offset_x and clip_offset_y columns to posts table if they don't exist"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    ALTER TABLE posts
                    ADD COLUMN IF NOT EXISTS clip_offset_x REAL DEFAULT 0
                """)
                cur.execute("""
                    ALTER TABLE posts
                    ADD COLUMN IF NOT EXISTS clip_offset_y REAL DEFAULT 0
                """)
                conn.commit()
                print("Migration: clip_offset_x and clip_offset_y columns added to posts")
        except Exception as e:
            conn.rollback()
            print(f"Migration error: {e}")
        finally:
            self.return_connection(conn)

    def migrate_add_ancestor_chains(self):
        """Add ancestor_chain column to users table and populate for existing users"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Add column if not exists
                cur.execute("""
                    ALTER TABLE users
                    ADD COLUMN IF NOT EXISTS ancestor_chain INTEGER[]
                """)
                conn.commit()
                print("Migration: ancestor_chain column added to users")

                # Get all users ordered by creation (oldest first ensures parents processed first)
                cur.execute("""
                    SELECT id, invited_by, ancestor_chain
                    FROM users
                    ORDER BY created_at ASC NULLS FIRST, id ASC
                """)
                users = cur.fetchall()

                updated = 0
                for user in users:
                    if user['ancestor_chain'] is not None:
                        continue  # Already has chain

                    if user['invited_by'] is None:
                        # Root user - chain is just themselves
                        chain = [user['id']]
                    else:
                        # Get inviter's chain
                        cur.execute(
                            "SELECT ancestor_chain FROM users WHERE id = %s",
                            (user['invited_by'],)
                        )
                        inviter = cur.fetchone()
                        if inviter and inviter['ancestor_chain']:
                            chain = [user['id']] + list(inviter['ancestor_chain'])
                        else:
                            # Inviter doesn't have chain yet, just use self + inviter
                            chain = [user['id'], user['invited_by']]

                    cur.execute(
                        "UPDATE users SET ancestor_chain = %s WHERE id = %s",
                        (chain, user['id'])
                    )
                    updated += 1

                conn.commit()
                print(f"Migration: Updated ancestor_chain for {updated} users")
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
                    "SELECT id, email, name, created_at, device_ids FROM users WHERE email = %s",
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
                    "SELECT id, email, name, created_at, device_ids, apns_device_token FROM users WHERE id = %s",
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

    def get_user_by_device_id(self, device_id: str) -> Optional[Dict[str, Any]]:
        """Get user by device ID"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT id, email, name, created_at, device_ids, invited_by, invited_at, profile_complete FROM users WHERE %s = ANY(device_ids)",
                    (device_id,)
                )
                return cur.fetchone()
        except Exception as e:
            print(f"Error getting user by device: {e}")
            return None
        finally:
            self.return_connection(conn)

    def create_user_from_invite(self, email: str, name: str, invited_by: int) -> Optional[int]:
        """Create a new user from an invitation, including ancestor chain"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Get inviter's ancestor chain
                cur.execute(
                    "SELECT ancestor_chain FROM users WHERE id = %s",
                    (invited_by,)
                )
                inviter = cur.fetchone()
                inviter_chain = inviter[0] if inviter and inviter[0] else [invited_by]

                # Insert new user
                cur.execute(
                    "INSERT INTO users (email, name, invited_by, invited_at, profile_complete) VALUES (%s, %s, %s, NOW(), FALSE) RETURNING id",
                    (email, name, invited_by)
                )
                user_id = cur.fetchone()[0]

                # Set ancestor chain: [new_user_id] + inviter's chain
                new_chain = [user_id] + list(inviter_chain)
                cur.execute(
                    "UPDATE users SET ancestor_chain = %s WHERE id = %s",
                    (new_chain, user_id)
                )

                conn.commit()
                return user_id
        except psycopg2.IntegrityError:
            conn.rollback()
            print(f"User with email {email} already exists")
            return None
        except Exception as e:
            conn.rollback()
            print(f"Error creating user from invite: {e}")
            return None
        finally:
            self.return_connection(conn)

    def get_proximity(self, user_a_id: int, user_b_id: int) -> int:
        """Calculate proximity between two users based on invite tree distance"""
        if user_a_id == user_b_id:
            return 0

        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, ancestor_chain FROM users WHERE id IN (%s, %s)",
                    (user_a_id, user_b_id)
                )
                rows = cur.fetchall()

                if len(rows) != 2:
                    return 9999  # User not found

                chains = {row[0]: row[1] or [] for row in rows}
                chain_a = chains.get(user_a_id, [])
                chain_b = chains.get(user_b_id, [])

                if not chain_a or not chain_b:
                    return 9999

                # Find common ancestor
                chain_b_set = set(chain_b)
                for i, ancestor in enumerate(chain_a):
                    if ancestor in chain_b_set:
                        distance_a = i
                        distance_b = chain_b.index(ancestor)
                        return distance_a + distance_b

                return 9999  # No common ancestor
        except Exception as e:
            print(f"Error calculating proximity: {e}")
            return 9999
        finally:
            self.return_connection(conn)

    def update_user_apns_token(self, user_id: int, apns_token: str) -> bool:
        """Update a user's APNs device token for push notifications"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE users SET apns_device_token = %s WHERE id = %s",
                    (apns_token, user_id)
                )
                conn.commit()
                return cur.rowcount > 0
        except Exception as e:
            conn.rollback()
            print(f"Error updating APNs token: {e}")
            return False
        finally:
            self.return_connection(conn)

    def get_all_users_with_push_tokens(self) -> List[Dict[str, Any]]:
        """Get all users who have APNs tokens registered"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT id, name, email, apns_device_token FROM users WHERE apns_device_token IS NOT NULL"
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting users with tokens: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_queries_matching_embedding(self, embedding: List[float], threshold: float = 0.3) -> List[Dict[str, Any]]:
        """Find all query posts that match a given embedding above threshold"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT p.id, p.title, p.user_id, u.name as user_name,
                           1 - (p.embedding <=> %s::vector) as similarity
                    FROM posts p
                    JOIN users u ON p.user_id = u.id
                    WHERE p.template_name = 'query'
                    AND p.embedding IS NOT NULL
                    AND 1 - (p.embedding <=> %s::vector) > %s
                """, (embedding, embedding, threshold))
                return cur.fetchall()
        except Exception as e:
            print(f"Error finding matching queries: {e}")
            return []
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

    def delete_post(self, post_id: int) -> bool:
        """
        Delete a post from the database.

        Args:
            post_id: ID of the post to delete

        Returns:
            True if successful, False otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Check if post exists
                cur.execute("SELECT id FROM posts WHERE id = %s", (post_id,))
                if cur.fetchone() is None:
                    return False

                # Delete the post (child posts will have parent_id set to NULL due to ON DELETE SET NULL)
                cur.execute("DELETE FROM posts WHERE id = %s", (post_id,))
                conn.commit()
                return True
        except Exception as e:
            conn.rollback()
            print(f"Error deleting post: {e}")
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
                           p.clip_offset_x, p.clip_offset_y,
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
                           p.clip_offset_x, p.clip_offset_y,
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
                           p.clip_offset_x, p.clip_offset_y,
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
                        p.image_url, p.clip_offset_x, p.clip_offset_y,
                        p.created_at, p.timezone, p.location_tag, p.ai_generated,
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
                    INSERT INTO posts (user_id, parent_id, title, summary, body, timezone, image_url, ai_generated, template_name)
                    VALUES (%s, -1, %s, %s, %s, %s, %s, false, 'profile')
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
        image_url: Optional[str] = None,
        clip_offset_x: Optional[float] = None,
        clip_offset_y: Optional[float] = None
    ) -> bool:
        """
        Update an existing post.

        Args:
            post_id: ID of post to update
            title: New title (optional)
            summary: New summary (optional)
            body: New body (optional)
            image_url: New image URL (optional)
            clip_offset_x: Image clip X offset -1 to 1 (optional)
            clip_offset_y: Image clip Y offset -1 to 1 (optional)

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

            if clip_offset_x is not None:
                updates.append("clip_offset_x = %s")
                params.append(max(-1.0, min(1.0, clip_offset_x)))

            if clip_offset_y is not None:
                updates.append("clip_offset_y = %s")
                params.append(max(-1.0, min(1.0, clip_offset_y)))

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
                           p.clip_offset_x, p.clip_offset_y,
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

    def get_recent_users(self, current_user_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get users ordered by proximity to current user, then by activity"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get current user's ancestor chain for proximity calculation
                current_chain = []
                if current_user_id:
                    cur.execute(
                        "SELECT ancestor_chain FROM users WHERE id = %s",
                        (current_user_id,)
                    )
                    result = cur.fetchone()
                    if result and result['ancestor_chain']:
                        current_chain = result['ancestor_chain']

                # Fetch all users with profiles
                cur.execute(
                    """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.clip_offset_x, p.clip_offset_y,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           u.ancestor_chain,
                           u.last_activity,
                           COUNT(children.id) as child_count
                    FROM users u
                    JOIN posts p ON p.user_id = u.id AND p.parent_id = -1
                    LEFT JOIN templates t ON p.template_name = t.name
                    LEFT JOIN posts children ON children.parent_id = p.id
                    GROUP BY p.id, u.id, u.email, u.name, u.ancestor_chain, u.last_activity,
                             t.placeholder_title, t.placeholder_summary, t.placeholder_body
                    """
                )
                users = cur.fetchall()

                # Calculate proximity for each user
                def calc_proximity(user_chain):
                    if not current_chain or not user_chain:
                        return 9999
                    chain_set = set(current_chain)
                    for i, ancestor in enumerate(user_chain):
                        if ancestor in chain_set:
                            return i + current_chain.index(ancestor)
                    return 9999

                # Add proximity to each result and sort
                for user in users:
                    user_chain = user.get('ancestor_chain') or []
                    user['proximity'] = calc_proximity(user_chain)

                # Sort by proximity (ascending), then by last_activity (descending, None last)
                users.sort(key=lambda u: (
                    u['proximity'],
                    u.get('last_activity') is None,  # None values last
                    -(u.get('last_activity').timestamp() if u.get('last_activity') else 0)
                ))

                return users
        except Exception as e:
            print(f"Error getting recent users: {e}")
            return []
        finally:
            self.return_connection(conn)

    def get_recent_tagged_posts(self, tags: List[str] = None, user_id: Optional[int] = None, limit: int = 50, current_user_email: Optional[str] = None, after: Optional[str] = None, current_user_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get recent posts filtered by template tags and optionally by user.

        For profile posts, incomplete profiles (empty summary AND body) are hidden
        unless they belong to the current user. Profiles are sorted by proximity first.

        Args:
            after: ISO8601 timestamp - only return posts created after this time
            current_user_id: ID of current user for proximity sorting (profiles)
        """
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get current user's ancestor chain for proximity sorting
                current_chain = []
                if current_user_id:
                    cur.execute(
                        "SELECT ancestor_chain FROM users WHERE id = %s",
                        (current_user_id,)
                    )
                    result = cur.fetchone()
                    if result and result['ancestor_chain']:
                        current_chain = result['ancestor_chain']

                # Build query
                query = """
                    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                           p.clip_offset_x, p.clip_offset_y,
                           p.created_at, p.timezone, p.location_tag, p.ai_generated,
                           p.template_name, p.has_new_matches,
                           t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name,
                           COALESCE(u.name, u.email) as author_name,
                           u.email as author_email,
                           u.ancestor_chain,
                           u.last_activity,
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

                # For profile posts, hide incomplete profiles unless they belong to current user
                if tags and "profile" in tags and current_user_email:
                    # Profile is complete if it has summary OR body content
                    # Always show current user's profile regardless of completeness
                    conditions.append("(COALESCE(p.summary, '') != '' OR COALESCE(p.body, '') != '' OR LOWER(u.email) = %s)")
                    params.append(current_user_email.lower())

                # Filter by timestamp if provided
                if after:
                    conditions.append("p.created_at > %s")
                    params.append(after)

                # Add WHERE clause if conditions exist
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)

                # Group by
                query += " GROUP BY p.id, p.has_new_matches, u.email, u.name, u.ancestor_chain, u.last_activity, t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name"

                # Sort order - if profile tag, we'll sort by proximity in Python
                # Otherwise sort by post date in SQL
                if not (tags and "profile" in tags):
                    query += " ORDER BY p.created_at DESC"

                # Add limit (but for profiles, we fetch all and sort by proximity, then limit)
                if not (tags and "profile" in tags):
                    query += " LIMIT %s"
                    params.append(limit)

                cur.execute(query, params)
                posts = cur.fetchall()

                # Helper to calculate proximity
                def calc_proximity(user_chain):
                    if not current_chain or not user_chain:
                        return 9999
                    chain_set = set(current_chain)
                    for i, ancestor in enumerate(user_chain):
                        if ancestor in chain_set:
                            return i + current_chain.index(ancestor)
                    return 9999

                # Calculate proximity for all posts
                for post in posts:
                    user_chain = post.get('ancestor_chain') or []
                    post['proximity'] = calc_proximity(user_chain)

                # Sort based on content type
                if tags and "profile" in tags:
                    # Profiles: proximity first, then activity
                    posts.sort(key=lambda p: (
                        p['proximity'],
                        p.get('last_activity') is None,
                        -(p.get('last_activity').timestamp() if p.get('last_activity') else 0)
                    ))
                    posts = posts[:limit]
                else:
                    # Posts/queries: date (day) first, proximity as tiebreaker within same day
                    def get_date_key(p):
                        created = p.get('created_at')
                        if created is None:
                            return (1, None, 9999)  # None dates sort last
                        # Sort by date (newest first), then proximity (closest first)
                        return (0, -created.toordinal(), p['proximity'])
                    posts.sort(key=get_date_key)

                return posts
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

    def create_search_cache_table(self):
        """Create search_cache table for LLM result caching"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS search_cache (
                        prompt_hash TEXT PRIMARY KEY,
                        model_name TEXT NOT NULL,
                        llm_results TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)

                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_search_cache_model
                    ON search_cache(model_name)
                """)

                conn.commit()
                print("Search cache table created successfully")
        except Exception as e:
            conn.rollback()
            print(f"Error creating search_cache table: {e}")
        finally:
            self.return_connection(conn)

    def create_query_results_table(self):
        """Create query_results table for cached search results"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Create query_results table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS query_results (
                        id SERIAL PRIMARY KEY,
                        query_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
                        post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
                        relevance_score FLOAT NOT NULL,
                        matched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE(query_id, post_id)
                    )
                """)

                # Create indexes for fast queries
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_query_results_query_id
                    ON query_results(query_id)
                """)

                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_query_results_score
                    ON query_results(query_id, relevance_score DESC)
                """)

                # Add has_new_matches column to posts table
                cur.execute("""
                    ALTER TABLE posts
                    ADD COLUMN IF NOT EXISTS has_new_matches BOOLEAN DEFAULT FALSE
                """)

                conn.commit()
                print("Query results table created successfully")
        except Exception as e:
            conn.rollback()
            print(f"Error creating query_results table: {e}")
        finally:
            self.return_connection(conn)

    def get_posts_by_template(self, template_name: str) -> List[tuple]:
        """Get all posts with specific template"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT id, user_id, parent_id, title, summary, body, image_url,
                           created_at, timezone, location_tag, ai_generated, template_name,
                           has_new_matches
                    FROM posts
                    WHERE template_name = %s
                """, (template_name,))
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting posts by template: {e}")
            return []
        finally:
            self.return_connection(conn)

    def insert_query_result(self, query_id: int, post_id: int, score: float):
        """Insert or update a query result match"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO query_results (query_id, post_id, relevance_score, matched_at)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (query_id, post_id)
                    DO UPDATE SET relevance_score = %s, matched_at = NOW()
                """, (query_id, post_id, score, score))
                conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error inserting query result: {e}")
        finally:
            self.return_connection(conn)

    def set_has_new_matches(self, query_id: int, value: bool):
        """Set the has_new_matches flag for a query"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE posts SET has_new_matches = %s WHERE id = %s
                """, (value, query_id))
                conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error setting has_new_matches: {e}")
        finally:
            self.return_connection(conn)

    def record_query_view(self, user_email: str, query_id: int):
        """Record that a user viewed a query's results"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO query_views (query_id, user_email, last_viewed_at)
                    VALUES (%s, %s, CURRENT_TIMESTAMP)
                    ON CONFLICT (query_id, user_email)
                    DO UPDATE SET last_viewed_at = CURRENT_TIMESTAMP
                """, (query_id, user_email))
                conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error recording query view: {e}")
        finally:
            self.return_connection(conn)

    def update_last_match_added(self, query_id: int):
        """Update the last_match_added_at timestamp for a query"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE posts
                    SET last_match_added_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (query_id,))
                conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error updating last_match_added_at: {e}")
        finally:
            self.return_connection(conn)

    def get_has_new_matches_bulk(self, user_email: str, query_ids: List[int]) -> dict:
        """Get has_new_matches flags for multiple queries for a specific user
        Returns: dict mapping query_id -> bool
        A query has new matches if:
        - last_match_added_at > last_viewed_at (or never viewed)
        """
        if not query_ids:
            return {}

        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # Check if last_match_added_at > last_viewed_at for each query
                # If user has never viewed a query, treat as having new matches if any matches exist
                cur.execute("""
                    SELECT
                        p.id,
                        CASE
                            WHEN qv.last_viewed_at IS NULL THEN
                                p.last_match_added_at IS NOT NULL
                            ELSE
                                p.last_match_added_at > qv.last_viewed_at
                        END as has_new
                    FROM posts p
                    LEFT JOIN query_views qv
                        ON p.id = qv.query_id
                        AND qv.user_email = %s
                    WHERE p.id = ANY(%s)
                """, (user_email, query_ids))
                results = cur.fetchall()
                return {row[0]: row[1] for row in results}
        except Exception as e:
            print(f"Error getting has_new_matches bulk: {e}")
            return {}
        finally:
            self.return_connection(conn)

    def get_query_results(self, query_id: int) -> List[tuple]:
        """Get cached results for a query, sorted by post creation date (most recent first)"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT qr.post_id, qr.relevance_score, qr.matched_at
                    FROM query_results qr
                    JOIN posts p ON qr.post_id = p.id
                    WHERE qr.query_id = %s
                    ORDER BY p.created_at DESC, qr.relevance_score DESC
                """, (query_id,))
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting query results: {e}")
            return []
        finally:
            self.return_connection(conn)

    def clear_query_results(self, query_id: int):
        """Clear all cached results for a query (used when query is edited)"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM query_results WHERE query_id = %s", (query_id,))
                conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error clearing query results: {e}")
        finally:
            self.return_connection(conn)

    def clear_post_from_results(self, post_id: int):
        """Clear all query results for a specific post (used when post is edited)"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM query_results WHERE post_id = %s", (post_id,))
                conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error clearing post from query results: {e}")
        finally:
            self.return_connection(conn)

# Global database instance
db = Database()
