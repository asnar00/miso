# Search - Python Implementation (Cached Results)

## Overview

The search system uses **background matching** instead of on-demand search:
- When posts are created → check against all queries → cache matches
- When queries are created → search all posts → cache matches
- When user taps query → read from cache (instant)

## Database Schema Changes

**Location**: `apps/firefly/product/server/imp/py/db.py`

### New Table: query_results

```sql
CREATE TABLE IF NOT EXISTS query_results (
    id SERIAL PRIMARY KEY,
    query_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
    relevance_score FLOAT NOT NULL,
    matched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(query_id, post_id)
);

CREATE INDEX idx_query_results_query_id ON query_results(query_id);
CREATE INDEX idx_query_results_score ON query_results(query_id, relevance_score DESC);
```

### Add Column to posts Table

```sql
ALTER TABLE posts ADD COLUMN IF NOT EXISTS has_new_matches BOOLEAN DEFAULT FALSE;
```

### Database Functions

```python
def get_posts_by_template(template_name):
    """Get all posts with specific template."""
    with db.get_cursor() as cur:
        cur.execute("""
            SELECT id, user_id, parent_id, title, summary, body, image_url,
                   created_at, timezone, location_tag, ai_generated, template_name,
                   has_new_matches
            FROM posts
            WHERE template_name = %s
        """, (template_name,))
        return cur.fetchall()

def insert_query_result(query_id, post_id, score):
    """Insert or update a query result match."""
    with db.get_cursor() as cur:
        cur.execute("""
            INSERT INTO query_results (query_id, post_id, relevance_score, matched_at)
            VALUES (%s, %s, %s, NOW())
            ON CONFLICT (query_id, post_id)
            DO UPDATE SET relevance_score = %s, matched_at = NOW()
        """, (query_id, post_id, score, score))
        db.commit()

def set_has_new_matches(query_id, value):
    """Set the has_new_matches flag for a query."""
    with db.get_cursor() as cur:
        cur.execute("""
            UPDATE posts SET has_new_matches = %s WHERE id = %s
        """, (value, query_id))
        db.commit()

def get_query_results(query_id):
    """Get cached results for a query, sorted by relevance."""
    with db.get_cursor() as cur:
        cur.execute("""
            SELECT post_id, relevance_score, matched_at
            FROM query_results
            WHERE query_id = %s
            ORDER BY relevance_score DESC
        """, (query_id,))
        return cur.fetchall()

def clear_query_results(query_id):
    """Clear all cached results for a query (used when query is edited)."""
    with db.get_cursor() as cur:
        cur.execute("DELETE FROM query_results WHERE query_id = %s", (query_id,))
        db.commit()
```

## API Endpoint Changes

**Location**: `apps/firefly/product/server/imp/py/app.py`

### Updated: GET /api/search

**Old behavior**: Compute search on-demand (5-7 seconds)
**New behavior**: Read from cache (instant)

```python
@app.route('/api/search', methods=['GET'])
def search_posts():
    """
    Get cached search results for a query.

    Query parameters:
        query_id: ID of the query post (required)

    Returns:
        JSON array of {id, relevance_score} objects
    """
    query_id = request.args.get('query_id', type=int)
    if not query_id:
        return jsonify({"error": "query_id required"}), 400

    # Read cached results
    results = db.get_query_results(query_id)

    # Clear new matches flag
    db.set_has_new_matches(query_id, False)

    # Return IDs and scores (client fetches full posts)
    return jsonify([{
        "id": post_id,
        "relevance_score": score / 100  # Normalize to 0-1 range
    } for post_id, score, _ in results])
```

### New: Background Post Matching

**Called when**: Any new post is created

```python
def check_post_against_queries(new_post_id):
    """
    Check a newly created post against all queries and cache matches.
    Runs in background after post creation.
    """
    import embeddings
    import torch
    import numpy as np

    # 1. Get all queries
    queries = db.get_posts_by_template('query')
    if len(queries) == 0:
        return

    # 2. Load new post embeddings
    new_post_embeddings = embeddings.load_embeddings(new_post_id)
    if new_post_embeddings is None:
        logger.warning(f"No embeddings found for post {new_post_id}")
        return

    # Convert to float32 for computation
    new_post_embeddings = new_post_embeddings.astype(np.float32) / 127.0

    # 3. Compute similarity against each query
    query_scores = []

    for query in queries:
        query_id = query[0]  # id is first column

        # Load query embeddings
        query_embeddings = embeddings.load_embeddings(query_id)
        if query_embeddings is None:
            continue

        query_embeddings = query_embeddings.astype(np.float32) / 127.0

        # Compute similarity matrix
        similarity_matrix = compute_similarity_gpu_matrix(query_embeddings, new_post_embeddings)

        # Use MAX aggregation
        max_similarity = np.max(similarity_matrix)

        query_scores.append((query_id, query, max_similarity))

    # 4. Sort by RAG score
    query_scores.sort(key=lambda x: x[2], reverse=True)

    # 5. Get new post data
    new_post = db.get_post_by_id(new_post_id)

    # 6. Process in batches of 20
    BATCH_SIZE = 20
    for batch_start in range(0, len(query_scores), BATCH_SIZE):
        batch = query_scores[batch_start:batch_start + BATCH_SIZE]

        try:
            # Call LLM to evaluate post against batch of queries
            batch_scores = llm_evaluate_post_against_queries(batch, new_post)

            # Store matches if relevant (score >= 40)
            for query_id, llm_score in batch_scores:
                if llm_score >= 40:
                    db.insert_query_result(query_id, new_post_id, llm_score)
                    db.set_has_new_matches(query_id, True)

        except Exception as e:
            # LLM failed, fall back to RAG scores
            logger.warning(f"LLM batch evaluation failed: {e}")

            for query_id, query, rag_score in batch:
                if rag_score >= 0.4:  # Equivalent to 40/100
                    db.insert_query_result(query_id, new_post_id, rag_score * 100)
                    db.set_has_new_matches(query_id, True)
```

### New: Initial Query Population

**Called when**: A new query is created

```python
def populate_initial_query_results(query_id):
    """
    When a new query is created, search all existing posts and cache results.
    This is the one-time "slow" operation (may take several seconds).
    """
    import embeddings
    import torch
    import numpy as np

    # Get query post
    query_post = db.get_post_by_id(query_id)
    if not query_post:
        return

    # Load query embeddings
    query_embeddings = embeddings.load_embeddings(query_id)
    if query_embeddings is None:
        logger.warning(f"No embeddings for query {query_id}")
        return

    query_embeddings = query_embeddings.astype(np.float32) / 127.0

    # Load all post embeddings
    all_embeddings, index = load_all_embeddings()
    all_embeddings = all_embeddings.astype(np.float32) / 127.0

    # Compute similarity matrix
    similarity_matrix = compute_similarity_gpu_matrix(query_embeddings, all_embeddings)

    # Aggregate scores per post using MAX
    post_similarities = {}
    for i, (post_id, frag_idx) in enumerate(index):
        if post_id == query_id:
            continue  # Skip query itself

        # Get similarities between all query fragments and this post fragment
        fragment_sims = similarity_matrix[:, i]

        if post_id not in post_similarities:
            post_similarities[post_id] = []
        post_similarities[post_id].extend(fragment_sims.tolist())

    # Compute MAX score for each post
    post_scores = {
        post_id: max(sims)
        for post_id, sims in post_similarities.items()
    }

    # Sort and get top 20 candidates
    ranked = sorted(post_scores.items(), key=lambda x: x[1], reverse=True)
    rag_candidates = ranked[:20]

    # Fetch full post content for candidates
    candidate_posts = []
    for post_id, rag_score in rag_candidates:
        post = db.get_post_by_id(post_id)
        if post and post.get('template_name') != 'query':
            candidate_posts.append({
                "id": post_id,
                "title": post['title'],
                "summary": post['summary'],
                "body": post['body'],
                "rag_score": rag_score
            })

    # LLM re-ranking (batch mode)
    try:
        llm_results = llm_rerank_posts(query_post, candidate_posts)

        # Store results
        for post_id, llm_score in llm_results:
            if llm_score >= 40:
                db.insert_query_result(query_id, post_id, llm_score)

    except Exception as e:
        # LLM failed, use RAG scores
        logger.warning(f"LLM re-ranking failed: {e}")

        for post in candidate_posts:
            db.insert_query_result(query_id, post['id'], post['rag_score'] * 100)
```

## LLM Evaluation Functions

**Location**: `apps/firefly/product/server/imp/py/app.py`

### Batched Post-to-Queries Evaluation

```python
def llm_evaluate_post_against_queries(query_batch, new_post):
    """
    Evaluate how relevant a new post is to a batch of queries.

    Args:
        query_batch: List of (query_id, query_row, rag_score) tuples
        new_post: Dict with 'title', 'summary', 'body'

    Returns:
        List of (query_id, score) tuples
    """
    from anthropic import Anthropic
    import json

    client = Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

    # Build prompt
    prompt = "You are a semantic search relevance evaluator. Below are search queries from users looking for specific content.\n\n"

    for query_id, query_row, rag_score in query_batch:
        # Extract query text from row (columns: id, user_id, parent_id, title, summary, body, ...)
        title = query_row[3]
        summary = query_row[4]
        body = query_row[5]
        query_text = f"{title} {summary} {body}"
        prompt += f"Query {query_id}: {query_text}\n\n"

    prompt += f"""A new post has just been created:
Title: {new_post['title']}
Summary: {new_post['summary']}
Body: {new_post['body']}

For EACH query above, score 0-100: Does this new post answer or match what that query is searching for? Would someone who created that query want to see this post in their results?

Evaluate each query:
- Does the post provide relevant information the query is looking for?
- Does it match the semantic intent and topic of the query?
- Would the query author find this post useful?

Return ONLY a JSON array with this exact format:
[{{"query_id": <id>, "score": <0-100>}}, ...]

Score from 0-100 where:
- 0-39: Not relevant (query author wouldn't want to see this)
- 40-59: Somewhat relevant
- 60-79: Relevant
- 80-100: Highly relevant (exactly what the query is looking for)

Include ALL queries in your response, even if score is 0.
"""

    response = client.messages.create(
        model="claude-3-5-haiku-20241022",
        max_tokens=1000,
        temperature=0.0,
        messages=[{"role": "user", "content": prompt}]
    )

    # Parse JSON response
    scores = json.loads(response.content[0].text)
    return [(item['query_id'], item['score']) for item in scores]
```

### Batch Post Re-ranking (for initial query population)

```python
def llm_rerank_posts(query_post, candidate_posts):
    """
    Re-rank candidate posts for a query using LLM.

    Args:
        query_post: Dict with 'title', 'summary', 'body'
        candidate_posts: List of dicts with 'id', 'title', 'summary', 'body'

    Returns:
        List of (post_id, score) tuples
    """
    from anthropic import Anthropic
    import json

    client = Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

    query_text = f"{query_post['title']} {query_post['summary']} {query_post['body']}"

    prompt = f"""You are a semantic search relevance evaluator. Given a search query and a list of posts, score each post's relevance to the query from 0-100.

Query: "{query_text}"

Posts to evaluate:
"""

    for i, post in enumerate(candidate_posts):
        prompt += f"""
Post {i+1} (ID: {post['id']}):
Title: {post['title']}
Summary: {post['summary']}
Body: {post['body']}
---
"""

    prompt += """
For each post, evaluate:
- How well does it match the semantic intent of the query?
- Is the content truly relevant or just superficially similar?
- Does it provide useful information related to the query?

Return ONLY a JSON array with this exact format:
[{"id": <post_id>, "score": <0-100>}, ...]

Score from 0-100 where:
- 0-39: Not relevant (will be filtered out)
- 40-59: Somewhat relevant
- 60-79: Relevant
- 80-100: Highly relevant

Sort by score descending (highest first).
"""

    response = client.messages.create(
        model="claude-3-5-haiku-20241022",
        max_tokens=2000,
        temperature=0.0,
        messages=[{"role": "user", "content": prompt}]
    )

    # Parse JSON response
    scores = json.loads(response.content[0].text)
    return [(item['id'], item['score']) for item in scores]
```

## Helper Functions

### GPU Similarity Computation

```python
def compute_similarity_gpu_matrix(query_embeddings, all_embeddings):
    """
    Compute cosine similarity matrix on GPU.

    Args:
        query_embeddings: numpy array (num_query_fragments, 768)
        all_embeddings: numpy array (total_fragments, 768)

    Returns:
        similarity_matrix: numpy array (num_query_fragments, total_fragments)
    """
    import torch

    device = "mps" if torch.backends.mps.is_available() else "cpu"

    # Convert to GPU tensors
    query_tensor = torch.from_numpy(query_embeddings).to(device)
    all_tensor = torch.from_numpy(all_embeddings).to(device)

    # L2 normalize
    query_norm = torch.nn.functional.normalize(query_tensor, p=2, dim=1)
    all_norm = torch.nn.functional.normalize(all_tensor, p=2, dim=1)

    # Matrix multiplication for cosine similarity
    similarity_matrix = torch.mm(query_norm, all_norm.t())

    return similarity_matrix.cpu().numpy()

def load_all_embeddings():
    """
    Load all post embeddings from disk.

    Returns:
        all_embeddings: numpy array (total_fragments, 768)
        index: list of (post_id, fragment_idx) tuples
    """
    import os
    import numpy as np

    embedding_files = []
    for filename in os.listdir('data/embeddings'):
        if filename.startswith('post_') and filename.endswith('.npy'):
            post_id = int(filename.replace('post_', '').replace('.npy', ''))
            embedding_files.append((post_id, f'data/embeddings/{filename}'))

    embedding_files.sort()

    all_embeddings = []
    index = []

    for post_id, filepath in embedding_files:
        emb = np.load(filepath)
        for frag_idx in range(len(emb)):
            index.append((post_id, frag_idx))
            all_embeddings.append(emb[frag_idx])

    return np.array(all_embeddings), index
```

## Integration Points

### Hook into Post Creation

In `app.py`, after creating a post:

```python
@app.route('/api/posts', methods=['POST'])
def create_post():
    # ... existing post creation logic ...

    # Generate embeddings
    embeddings.generate_embeddings_for_post(post_id, title, summary, body)

    # Check post against all queries (background matching)
    check_post_against_queries(post_id)

    # If this is a query, populate initial results
    if template_name == 'query':
        populate_initial_query_results(post_id)

    return jsonify({"post": post_data}), 201
```

### Hook into Post Editing

When a post is edited, regenerate embeddings and re-check:

```python
@app.route('/api/posts/<int:post_id>', methods=['PUT'])
def update_post(post_id):
    # ... existing post update logic ...

    # Regenerate embeddings
    embeddings.generate_embeddings_for_post(post_id, title, summary, body)

    # If this is a query, clear and regenerate results
    post = db.get_post_by_id(post_id)
    if post.get('template_name') == 'query':
        db.clear_query_results(post_id)
        populate_initial_query_results(post_id)
    else:
        # Regular post - re-check against all queries
        check_post_against_queries(post_id)

    return jsonify({"post": post_data})
```

## Performance Considerations

- **Background matching**: Runs after post creation, doesn't block user
- **Batched LLM calls**: 20 queries per call (100 queries = 5 sequential calls)
- **GPU acceleration**: All similarity computation on M2 GPU (MPS)
- **Cached reads**: Query results are instant (just database read)
- **Database indexing**: Indexes on query_id and relevance_score for fast reads

## Migration Script

```python
# Run once to create new table and column
def migrate_search_cache():
    with db.get_cursor() as cur:
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

        # Create indexes
        cur.execute("CREATE INDEX IF NOT EXISTS idx_query_results_query_id ON query_results(query_id)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_query_results_score ON query_results(query_id, relevance_score DESC)")

        # Add column to posts
        cur.execute("ALTER TABLE posts ADD COLUMN IF NOT EXISTS has_new_matches BOOLEAN DEFAULT FALSE")

        db.commit()

    # Populate initial results for existing queries
    queries = db.get_posts_by_template('query')
    for query in queries:
        query_id = query[0]
        populate_initial_query_results(query_id)
```

## Badge Polling System

### Database Schema Additions

**New table for per-user query views**:
```sql
CREATE TABLE IF NOT EXISTS query_views (
    id SERIAL PRIMARY KEY,
    query_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_email VARCHAR(255) NOT NULL,
    last_viewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(query_id, user_email)
);

CREATE INDEX IF NOT EXISTS idx_query_views_query_user ON query_views(query_id, user_email);
```

**New column on posts table**:
```sql
ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_match_added_at TIMESTAMP;
```

**Migration script**: `migrate_query_views.sql` contains the above DDL statements.

### Database Functions (db.py)

**Record query view**:
```python
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
    finally:
        self.return_connection(conn)
```

**Update last match timestamp**:
```python
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
    finally:
        self.return_connection(conn)
```

**Bulk badge checking**:
```python
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
    finally:
        self.return_connection(conn)
```

**Key query logic**:
- `LEFT JOIN` ensures we get results even if user never viewed the query
- `CASE WHEN qv.last_viewed_at IS NULL`: User never viewed → check if timestamps exist
- `ELSE p.last_match_added_at > qv.last_viewed_at`: User viewed before → compare timestamps
- Uses `ANY(%s)` for efficient IN clause with array parameter

### API Endpoints (app.py)

**Badge polling endpoint**:
```python
@app.route('/api/queries/badges', methods=['POST'])
def get_query_badges():
    """Get has_new_matches flags for multiple queries for a user
    Request body: {"user_email": "user@example.com", "query_ids": [1, 2, 3, ...]}
    Response: {"1": true, "2": false, ...}"""
    try:
        data = request.get_json()
        user_email = data.get('user_email', '')
        query_ids = data.get('query_ids', [])
        
        if not user_email:
            return jsonify({'error': 'user_email is required'}), 400
        
        if not query_ids:
            return jsonify({}), 200
        
        # Get flags from database for this user
        flags = db.get_has_new_matches_bulk(user_email, query_ids)
        
        # Convert to string keys for JSON
        response = {str(k): v for k, v in flags.items()}
        
        return jsonify(response), 200
    except Exception as e:
        logger.error(f"[BADGES] Error getting badges: {e}")
        return jsonify({'error': str(e)}), 500
```

**Updated search endpoint** (records view):
```python
@app.route('/api/search', methods=['GET'])
def search_posts():
    """Get cached search results for a query (instant, with auto-populate fallback)"""
    try:
        query_id = request.args.get('query_id', '').strip()
        user_email = request.args.get('user_email', '').strip()  # NEW parameter

        if not query_id:
            return jsonify({'error': 'Query parameter query_id is required'}), 400

        query_id = int(query_id)
        logger.info(f"[SEARCH] Getting cached results for query {query_id}")

        # Read cached results
        results = db.get_query_results(query_id)

        # If cache is empty, populate it now
        if len(results) == 0:
            logger.info(f"[SEARCH] Cache empty for query {query_id}, populating now...")
            populate_initial_query_results(query_id)
            results = db.get_query_results(query_id)
            logger.info(f"[SEARCH] Populated cache with {len(results)} results")

        # Record that this user viewed this query (NEW)
        if user_email:
            db.record_query_view(user_email, query_id)

        # Return IDs and scores
        response = [{
            'id': post_id,
            'relevance_score': score / 100.0
        } for post_id, score, _ in results]

        return jsonify(response), 200
    except Exception as e:
        logger.error(f"[SEARCH] Error: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500
```

**Key changes**:
- Accept optional `user_email` query parameter
- Call `db.record_query_view()` if email provided
- This records/updates the view timestamp in `query_views` table

### Background Matching Updates

**Update `check_post_against_queries()`** to set timestamp:
```python
def check_post_against_queries(new_post_id: int):
    # ... existing RAG and LLM logic ...

    try:
        # LLM batch evaluation
        batch_scores = llm_evaluate_post_against_queries(batch, new_post)
        
        matches_added = False
        for (query_id, llm_score) in batch_scores:
            if llm_score >= 40:
                db.insert_query_result(query_id, new_post_id, llm_score)
                matches_added = True

        # NEW: Update timestamp if any matches were added
        if matches_added:
            db.update_last_match_added(query_id)

    except Exception as e:
        # LLM failed, fall back to RAG scores
        for (query_id, query, rag_score) in batch:
            if rag_score >= 0.4:
                db.insert_query_result(query_id, new_post_id, rag_score * 100)
        
        # NEW: Update timestamp for RAG matches too
        db.update_last_match_added(query_id)
```

**Update `populate_initial_query_results()`** to set timestamp:
```python
def populate_initial_query_results(query_id: int):
    # ... existing full search logic ...

    try:
        llm_results = llm_rerank_posts(query_post, candidate_posts)

        matches_added = False
        for item in llm_results:
            if item['score'] >= 40:
                db.insert_query_result(query_id, item['id'], item['score'])
                matches_added = True

        # NEW: Set timestamp if matches were added
        if matches_added:
            db.update_last_match_added(query_id)

    except Exception as e:
        # LLM failed, use RAG scores
        if candidate_posts:
            for post in candidate_posts:
                db.insert_query_result(query_id, post['id'], post['rag_score'] * 100)
            # NEW: Set timestamp for RAG results too
            db.update_last_match_added(query_id)
```

### Migration Utility

**populate_query_timestamps.py** - One-time script to set initial timestamps:
```python
#!/usr/bin/env python3
"""
Populate last_match_added_at timestamps for all queries that have cached results.
Sets the timestamp to the time the most recent match was added.
"""

import sys
from db import db

def main():
    print("Fetching all query posts...")
    queries = db.get_posts_by_template('query')

    if not queries:
        print("No queries found in database.")
        return

    print(f"Found {len(queries)} queries to process\n")

    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            for i, query in enumerate(queries, 1):
                query_id = query[0]
                query_title = query[3]

                # Check if this query has any cached results
                cur.execute("""
                    SELECT COUNT(*) FROM query_results WHERE query_id = %s
                """, (query_id,))
                count = cur.fetchone()[0]

                if count == 0:
                    print(f"[{i}/{len(queries)}] Query '{query_title}' (ID: {query_id}) - no results, skipping")
                    continue

                # Set last_match_added_at to now
                cur.execute("""
                    UPDATE posts
                    SET last_match_added_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (query_id,))

                print(f"[{i}/{len(queries)}] Query '{query_title}' (ID: {query_id}) - set timestamp ({count} results)")

            conn.commit()
            print("\nDone! All query timestamps populated.")

    finally:
        conn.close()

if __name__ == "__main__":
    main()
```

**Usage**:
```bash
cd apps/firefly/product/server/imp/py/
python3 populate_query_timestamps.py
```

### Testing the Badge System

**Manual test** - Verify badges endpoint works:
```bash
# Check current state
curl -X POST http://185.96.221.52:8080/api/queries/badges \
  -H "Content-Type: application/json" \
  -d '{"user_email": "test@example.com", "query_ids": [30, 31, 32, 35]}'

# Should return: {"30": false, "31": true, "32": true, "35": true}
```

**Manually set badge** - Test timestamp manipulation:
```bash
# Make badge appear (set last_match_added_at to now)
ssh microserver@185.96.221.52 \
  "psql -U firefly_user -d firefly -c \"UPDATE posts SET last_match_added_at = CURRENT_TIMESTAMP WHERE id = 35;\""

# Make badge disappear (record user viewed it)
ssh microserver@185.96.221.52 \
  "psql -U firefly_user -d firefly -c \"INSERT INTO query_views (query_id, user_email, last_viewed_at) VALUES (35, 'test@example.com', CURRENT_TIMESTAMP) ON CONFLICT (query_id, user_email) DO UPDATE SET last_viewed_at = CURRENT_TIMESTAMP;\""
```

**Check database state**:
```bash
ssh microserver@185.96.221.52 \
  "psql -U firefly_user -d firefly -c \"SELECT p.id, p.title, p.last_match_added_at, qv.last_viewed_at FROM posts p LEFT JOIN query_views qv ON p.id = qv.query_id AND qv.user_email = 'test@example.com' WHERE p.template_name = 'query' ORDER BY p.id;\""
```

### Performance Characteristics

**Badge endpoint**:
- Single database query with LEFT JOIN
- Returns only boolean flags (minimal data transfer)
- Efficient even with many queries (batch operation)
- Query uses index on `(query_id, user_email)`

**Polling frequency**:
- 5 second interval (configurable in iOS client)
- Only polls when query list is visible
- Stops immediately on navigation away

**Database load**:
- One query per poll interval per active user viewing queries
- JOIN is indexed and fast
- No full table scans
- Scales linearly with concurrent users

### Multi-User Architecture Benefits

**Independent user state**:
- Each user has own `last_viewed_at` for each query
- User A viewing query doesn't affect User B's badge
- Supports future query sharing features

**Timestamp-based approach**:
- More flexible than boolean flags
- Allows rich badge logic (e.g., "new matches in last hour")
- Can add badge count in future: `COUNT(*)` of matches after last view
- Natural ordering for "newest first" features

**Future extensibility**:
- Can add read receipts ("User A viewed your query")
- Can track engagement metrics (view frequency, time spent)
- Can implement notifications ("3 new matches for your 'food' query")
