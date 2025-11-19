"""
Database module for Firefly server using SQLite.
Simple, reliable, zero-configuration database with no connection pool issues.
"""

import sqlite3
import json
from typing import Optional, List, Dict, Any
import os
from datetime import datetime
import sys

class Database:
    """Database connection and operations manager for SQLite"""

    def __init__(self, db_path: Optional[str] = None):
        """
        Initialize database connection.

        Args:
            db_path: Path to SQLite database file. If None, uses 'firefly.db'
        """
        if db_path is None:
            db_path = os.path.join(os.path.dirname(__file__), 'firefly.db')

        self.db_path = db_path
        self._ensure_schema()

    def _dict_factory(self, cursor, row):
        """Convert sqlite3 rows to dictionaries"""
        fields = [column[0] for column in cursor.description]
        return {key: value for key, value in zip(fields, row)}

    def get_connection(self):
        """Get a database connection"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = self._dict_factory
        # Enable foreign keys
        conn.execute('PRAGMA foreign_keys = ON')
        return conn

    def return_connection(self, conn):
        """Close a connection (no pooling needed with SQLite)"""
        if conn:
            try:
                conn.close()
            except:
                pass

    def close_all_connections(self):
        """No-op for SQLite (no connection pool)"""
        pass

    def _ensure_schema(self):
        """Create tables if they don't exist"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()

            # Users table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    email TEXT NOT NULL UNIQUE,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    device_ids TEXT DEFAULT '[]',
                    name TEXT,
                    last_activity TEXT
                )
            """)
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")

            # Templates table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS templates (
                    name TEXT PRIMARY KEY,
                    placeholder_title TEXT NOT NULL,
                    placeholder_summary TEXT NOT NULL,
                    placeholder_body TEXT NOT NULL,
                    plural_name TEXT
                )
            """)

            # Posts table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS posts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    parent_id INTEGER,
                    title TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    body TEXT NOT NULL,
                    image_url TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    timezone TEXT NOT NULL,
                    location_tag TEXT,
                    ai_generated INTEGER NOT NULL DEFAULT 0,
                    template_name TEXT DEFAULT 'post',
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                )
            """)
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_posts_parent_id ON posts(parent_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC)")

            # Insert default templates
            cursor.execute("""
                INSERT OR IGNORE INTO templates (name, placeholder_title, placeholder_summary, placeholder_body, plural_name)
                VALUES ('post', 'Title', 'Summary', 'Body', 'posts')
            """)
            cursor.execute("""
                INSERT OR IGNORE INTO templates (name, placeholder_title, placeholder_summary, placeholder_body, plural_name)
                VALUES ('profile', 'name', 'mission', 'personal statement', 'profiles')
            """)
            cursor.execute("""
                INSERT OR IGNORE INTO templates (name, placeholder_title, placeholder_summary, placeholder_body, plural_name)
                VALUES ('query', 'query title', 'query', 'query details', 'queries')
            """)

            conn.commit()
            print(f"[DB] SQLite database initialized at {self.db_path}")

        except Exception as e:
            print(f"[DB] Error ensuring schema: {e}")
            conn.rollback()
            raise
        finally:
            self.return_connection(conn)

    # Helper methods for device_ids array (stored as JSON)
    def _encode_device_ids(self, device_ids: List[str]) -> str:
        """Convert Python list to JSON string"""
        return json.dumps(device_ids or [])

    def _decode_device_ids(self, device_ids_json: str) -> List[str]:
        """Convert JSON string to Python list"""
        try:
            return json.loads(device_ids_json or '[]')
        except:
            return []

# Global database instance
db = Database()
