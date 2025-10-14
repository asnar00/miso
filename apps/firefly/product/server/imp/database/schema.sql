-- Firefly Database Schema
-- PostgreSQL 16+ with pgvector extension

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    device_ids TEXT[] DEFAULT ARRAY[]::TEXT[]
);

-- Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

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

-- Grant permissions (adjust as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO firefly_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO firefly_user;
