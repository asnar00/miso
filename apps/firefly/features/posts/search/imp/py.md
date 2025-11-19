# Search - Python Implementation

## API Endpoint: /api/search

**Location**: `apps/firefly/product/server/imp/py/app.py`

**Purpose**: Semantic search endpoint that finds posts by comparing query embeddings against all post fragment embeddings using GPU-accelerated similarity computation.

## Implementation

### Endpoint Definition

```python
@app.route('/api/search', methods=['GET'])
def search_posts():
    """
    Search for posts using semantic similarity.

    Query parameters:
        q: Search query string (required)
        limit: Maximum number of results (default: 20)

    Returns:
        JSON array of {id, relevance_score} objects, ordered by relevance
        Client fetches full post data using /api/posts/{id} endpoint
    """
```

### Search Algorithm

1. **Load all embeddings from disk**:
   - Scan `data/embeddings/` directory for all `post_*.npy` files
   - Load each file and build index mapping: `[(post_id, fragment_idx), ...]`
   - Concatenate all embeddings into single numpy array

2. **Generate query embedding**:
   - Use embeddings.py `get_model()` to get the sentence transformer
   - Encode the query string: `query_emb = model.encode([query])`
   - Keep as float32 (no quantization - discovered that int8 degraded quality)

3. **GPU-accelerated similarity search**:
   - Convert embeddings and query to PyTorch tensors on GPU (MPS device for M2)
   - Compute cosine similarity between query and all fragments
   - Get similarity scores for each fragment

4. **Rank posts by best fragment match**:
   - Group fragments by post_id
   - Take maximum score per post (best matching fragment)
   - Sort posts by score (descending)
   - Filter out results with score < 0.25 (low relevance threshold)
   - Apply limit

5. **Return minimal results**:
   - Return only post IDs and relevance scores
   - Client fetches full post data using /api/posts/{id}
   - This ensures search results include all fields (child_count, etc.)

### Code Structure

```python
import os
import numpy as np
import torch
import embeddings
from db import db

def load_all_embeddings():
    """
    Load all post embeddings from disk.

    Returns:
        all_embeddings: numpy array of shape (total_fragments, 768) dtype int8
        index: list of (post_id, fragment_idx) tuples
    """
    embedding_files = []
    for filename in os.listdir('data/embeddings'):
        if filename.startswith('post_') and filename.endswith('.npy'):
            post_id = int(filename.replace('post_', '').replace('.npy', ''))
            embedding_files.append((post_id, f'data/embeddings/{filename}'))

    embedding_files.sort()  # Sort by post_id for consistency

    all_embeddings = []
    index = []

    for post_id, filepath in embedding_files:
        emb = np.load(filepath)  # Shape: (num_fragments, 768)
        all_embeddings.append(emb)
        for frag_idx in range(emb.shape[0]):
            index.append((post_id, frag_idx))

    all_embeddings = np.vstack(all_embeddings)  # Shape: (total_fragments, 768)
    return all_embeddings, index

def compute_similarity_gpu(query_emb, all_embeddings):
    """
    Compute cosine similarity on GPU using PyTorch.

    Args:
        query_emb: float32 array of shape (768,)
        all_embeddings: float32 array of shape (N, 768)

    Returns:
        scores: numpy array of shape (N,) with similarity scores
    """
    # Convert to PyTorch tensors on GPU
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    query_tensor = torch.tensor(query_emb, device=device, dtype=torch.float32).unsqueeze(0)  # Shape: (1, 768)
    all_tensor = torch.tensor(all_embeddings, device=device, dtype=torch.float32)  # Shape: (N, 768)

    # Compute cosine similarity
    scores = torch.nn.functional.cosine_similarity(query_tensor, all_tensor)

    # Convert back to numpy
    return scores.cpu().numpy()

@app.route('/api/search', methods=['GET'])
def search_posts():
    """Search for posts using semantic similarity"""
    try:
        # Get query parameter
        query = request.args.get('q', '').strip()
        if not query:
            return jsonify({'error': 'Query parameter q is required'}), 400

        limit = int(request.args.get('limit', 20))

        print(f"[SEARCH] Query: {query}, Limit: {limit}")

        # Load all embeddings
        all_embeddings, index = load_all_embeddings()
        print(f"[SEARCH] Loaded {len(index)} fragments from {len(set(pid for pid, _ in index))} posts")

        # Generate query embedding
        model = embeddings.get_model()
        query_emb = model.encode([query], convert_to_numpy=True)[0]  # Shape: (768,)

        # Compute similarity scores
        scores = compute_similarity_gpu(query_emb, all_embeddings)

        # Group by post_id and take max score
        post_scores = {}
        for i, (post_id, frag_idx) in enumerate(index):
            if post_id not in post_scores:
                post_scores[post_id] = scores[i]
            else:
                post_scores[post_id] = max(post_scores[post_id], scores[i])

        # Sort by score
        ranked_posts = sorted(post_scores.items(), key=lambda x: x[1], reverse=True)

        # Filter out query posts and low-scoring results (check template_name in database)
        filtered_posts = []
        for post_id, score in ranked_posts:
            # Skip results with relevance score below 0.25
            if score < 0.25:
                continue
            post = db.get_post_by_id(post_id)
            if post and post.get('template_name') != 'query':
                filtered_posts.append((post_id, score))
            if len(filtered_posts) >= limit:
                break

        print(f"[SEARCH] Top {len(filtered_posts)} posts (after filtering):")
        for post_id, score in filtered_posts[:5]:
            print(f"  Post {post_id}: {score:.3f}")

        # Return just post IDs and scores - client will fetch full details
        results = [{'id': post_id, 'relevance_score': float(score)} for post_id, score in filtered_posts]
        return jsonify(results)

    except Exception as e:
        print(f"[SEARCH] Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
```

## Integration with app.py

Add at the top of app.py:
```python
import embeddings
```

Add the helper functions and endpoint after existing routes.

## Testing

Test from command line:
```bash
curl "http://185.96.221.52:8080/api/search?q=test%20query&limit=5"
```

Expected response:
```json
[
  {
    "id": 10,
    "relevance_score": 0.2976
  },
  {
    "id": 13,
    "relevance_score": 0.2877
  },
  {
    "id": 22,
    "relevance_score": 0.2426
  }
]
```

## Critical Fix: Add child_count to get_post_by_id

**File**: `apps/firefly/product/server/imp/py/db.py`

The `/api/posts/{id}` endpoint must include `child_count` so search results can display navigate-to-children arrows (">").

Update `get_post_by_id()` method:

```python
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
```

The critical line is:
```sql
(SELECT COUNT(*) FROM posts WHERE parent_id = p.id) as child_count
```

This was discovered during debugging when search results showed posts but no ">" arrows appeared - the navigate-to-children buttons rely on `post.childCount > 0` in the iOS client.
