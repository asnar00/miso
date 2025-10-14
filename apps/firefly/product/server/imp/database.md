# database
*PostgreSQL vector database for users and posts*

The Firefly server uses PostgreSQL 16+ with the pgvector extension to store user accounts and posts with semantic search capabilities.

## Architecture

**PostgreSQL 16** provides the relational database foundation, storing:
- User accounts with email authentication and device associations
- Posts with hierarchical tree structure (parent-child relationships)
- Post metadata (timestamps, locations, AI-generated flags)

**pgvector** adds vector similarity search, enabling:
- Semantic search across posts using 768-dimensional embeddings
- Fast HNSW (Hierarchical Navigable Small World) indexing
- Cosine similarity queries for natural language search

## Schema Overview

### Users Table
- `id` - Primary key
- `email` - Unique email address for authentication
- `created_at` - Account creation timestamp
- `device_ids` - Array of device IDs associated with account

### Posts Table
- `id` - Primary key
- `user_id` - Foreign key to users table
- `parent_id` - Self-referencing foreign key for tree structure
- `title` - Post title
- `summary` - One-line summary
- `body` - Post content (up to ~300 words)
- `image_url` - Optional image URL
- `created_at` - Post timestamp (UTC)
- `timezone` - User's local timezone
- `location_tag` - Optional location
- `ai_generated` - Boolean flag for AI-generated content
- `embedding` - vector(768) for semantic search

## Database Module (db.py)

The Python database module provides:

**Connection Management:**
- Connection pooling for efficient resource usage
- Environment variable configuration
- Automatic connection lifecycle handling

**User Operations:**
- `create_user(email)` - Register new user
- `get_user_by_email(email)` - Look up user by email
- `get_user_by_id(user_id)` - Look up user by ID
- `add_device_to_user(user_id, device_id)` - Associate device with user

**Post Operations:**
- `create_post(...)` - Create new post with optional embedding
- `get_post_by_id(post_id)` - Retrieve single post
- `get_posts_by_user(user_id)` - Get all posts by user
- `get_child_posts(parent_id)` - Get children of a post (for trees)
- `get_recent_posts(limit)` - Get most recent posts

**Search Operations:**
- `search_posts_by_embedding(query_embedding, limit, threshold)` - Semantic similarity search

## Environment Variables

Configure database connection via environment variables:

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=firefly
export DB_USER=firefly_user
export DB_PASSWORD=firefly_pass
```

## Installation

See `database/install.md` for complete setup instructions on macOS and Linux servers.

## Testing

Run the test suite to verify database functionality:

```bash
cd apps/firefly/product/server/imp/py
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=firefly
export DB_USER=firefly_user
export DB_PASSWORD=firefly_pass
python3 test_db.py
```

Tests verify:
- Database connectivity
- User CRUD operations
- Post CRUD operations
- Vector similarity search
- Hierarchical relationships

## Performance

**Indexes:**
- B-tree indexes on `users.email`, `posts.user_id`, `posts.parent_id`
- HNSW vector index on `posts.embedding` for fast similarity search

**HNSW Index:**
- Approximate nearest neighbor search with high recall
- Sub-linear query time complexity
- Optimized for cosine similarity (vector_cosine_ops)

## Embedding Dimensions

Posts use 768-dimensional embeddings, matching the output of the `sentence-transformers` model (all-MiniLM-L6-v2 or similar). This provides a good balance between:
- Semantic representation quality
- Storage requirements (~3KB per embedding)
- Query performance
