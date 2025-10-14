-- Posts table schema for Firefly
-- Stores user posts with hierarchical structure and vector embeddings for semantic search

-- Posts table with hierarchical structure and embeddings
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    timezone VARCHAR(50) NOT NULL,
    location_tag TEXT,
    ai_generated BOOLEAN NOT NULL DEFAULT FALSE,
    embedding vector(768)  -- Using 768 dimensions for sentence-transformers
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_parent_id ON posts(parent_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);

-- Create vector similarity search index (HNSW for better performance)
CREATE INDEX IF NOT EXISTS idx_posts_embedding ON posts
USING hnsw (embedding vector_cosine_ops);

-- Comments
COMMENT ON TABLE posts IS 'User posts with vector embeddings for semantic search';
COMMENT ON COLUMN posts.id IS 'Unique post identifier';
COMMENT ON COLUMN posts.user_id IS 'ID of user who created this post';
COMMENT ON COLUMN posts.parent_id IS 'ID of parent post (NULL for root posts)';
COMMENT ON COLUMN posts.title IS 'Post title';
COMMENT ON COLUMN posts.summary IS 'One-line post summary';
COMMENT ON COLUMN posts.body IS 'Post body text (up to ~300 words)';
COMMENT ON COLUMN posts.image_url IS 'Optional URL to post image';
COMMENT ON COLUMN posts.created_at IS 'Post creation timestamp (UTC)';
COMMENT ON COLUMN posts.timezone IS 'User timezone when post was created';
COMMENT ON COLUMN posts.location_tag IS 'Optional location tag';
COMMENT ON COLUMN posts.ai_generated IS 'Whether this post was AI-generated';
COMMENT ON COLUMN posts.embedding IS '768-dimensional vector embedding for semantic search';
