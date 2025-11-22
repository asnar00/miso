-- Add last_match_added_at column to posts table
ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_match_added_at TIMESTAMP;

-- Create query_views table to track when users last viewed each query
CREATE TABLE IF NOT EXISTS query_views (
    id SERIAL PRIMARY KEY,
    query_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_email VARCHAR(255) NOT NULL,
    last_viewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(query_id, user_email)
);

CREATE INDEX IF NOT EXISTS idx_query_views_query_user ON query_views(query_id, user_email);
