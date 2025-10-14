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

    def initialize_pool(self, minconn=1, maxconn=10):
        """Initialize the connection pool"""
        try:
            self.connection_pool = psycopg2.pool.SimpleConnectionPool(
                minconn, maxconn, **self.db_config
            )
            print(f"Database connection pool initialized: {self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}")
        except Exception as e:
            print(f"Error initializing database pool: {e}")
            raise

    def get_connection(self):
        """Get a connection from the pool"""
        if self.connection_pool is None:
            self.initialize_pool()
        return self.connection_pool.getconn()

    def return_connection(self, conn):
        """Return a connection to the pool"""
        if self.connection_pool:
            self.connection_pool.putconn(conn)

    def close_all_connections(self):
        """Close all connections in the pool"""
        if self.connection_pool:
            self.connection_pool.closeall()

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
        embedding: Optional[List[float]] = None
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

        Returns:
            Post ID if successful, None otherwise
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO posts
                    (user_id, parent_id, title, summary, body, image_url, timezone, location_tag, ai_generated, embedding)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                    """,
                    (user_id, parent_id, title, summary, body, image_url, timezone, location_tag, ai_generated, embedding)
                )
                post_id = cur.fetchone()[0]
                conn.commit()
                return post_id
        except Exception as e:
            conn.rollback()
            print(f"Error creating post: {e}")
            return None
        finally:
            self.return_connection(conn)

    def get_post_by_id(self, post_id: int) -> Optional[Dict[str, Any]]:
        """Get a post by ID"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT id, user_id, parent_id, title, summary, body, image_url,
                           created_at, timezone, location_tag, ai_generated
                    FROM posts
                    WHERE id = %s
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
                    SELECT id, user_id, parent_id, title, summary, body, image_url,
                           created_at, timezone, location_tag, ai_generated
                    FROM posts
                    WHERE user_id = %s
                    ORDER BY created_at DESC
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
        """Get all child posts of a parent post"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT id, user_id, parent_id, title, summary, body, image_url,
                           created_at, timezone, location_tag, ai_generated
                    FROM posts
                    WHERE parent_id = %s
                    ORDER BY created_at ASC
                    """,
                    (parent_id,)
                )
                return cur.fetchall()
        except Exception as e:
            print(f"Error getting child posts: {e}")
            return []
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
                        id, user_id, parent_id, title, summary, body, image_url,
                        created_at, timezone, location_tag, ai_generated,
                        1 - (embedding <=> %s::vector) as similarity
                    FROM posts
                    WHERE embedding IS NOT NULL
                    AND 1 - (embedding <=> %s::vector) >= %s
                    ORDER BY embedding <=> %s::vector
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
        """Get most recent posts"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT id, user_id, parent_id, title, summary, body, image_url,
                           created_at, timezone, location_tag, ai_generated
                    FROM posts
                    ORDER BY created_at DESC
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

# Global database instance
db = Database()
