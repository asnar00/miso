# Search - Pseudocode

## Core Data Structures

```
SearchResult {
    id: int
    relevance_score: float  // 0.0 to 1.0, cosine similarity
}

PostFragment {
    post_id: int
    fragment_index: int
    embedding: float[768]  // Stored as float32
}

// New database tables for caching
query_results table:
    id: serial primary key
    query_id: int (foreign key to posts.id)
    post_id: int (foreign key to posts.id)
    relevance_score: float  // LLM score 0-100, or RAG score if LLM failed
    matched_at: timestamp
    unique(query_id, post_id)

query_views table:
    id: serial primary key
    query_id: int (foreign key to posts.id)
    user_email: varchar(255)
    last_viewed_at: timestamp
    unique(query_id, user_email)
    index on (query_id, user_email)

// New fields added to posts table for queries
posts table additions:
    last_match_added_at: timestamp  // Set when new match added to query
```

## Server: Background Post Matching (NEW)

**Called when**: Any new post is created (including queries)

```
function check_post_against_queries(new_post_id: int):
    // 1. Fetch all queries from database
    all_queries = database.get_posts_by_template('query')

    if len(all_queries) == 0:
        return  // No queries to check against

    // 2. Load new post embeddings
    new_post_embeddings = load_embeddings_from_disk(new_post_id)

    // 3. For each query, compute similarity
    query_scores = []

    for query in all_queries:
        // Load query embeddings
        query_embeddings = load_embeddings_from_disk(query.id)

        // Compute similarity matrix: all query fragments × all new post fragments
        similarity_matrix = compute_similarity_matrix_gpu(query_embeddings, new_post_embeddings)

        // Aggregate using MAX (best match across all fragment pairs)
        max_similarity = max(similarity_matrix)

        query_scores.append((query.id, query, max_similarity))

    // 4. Sort by RAG score and process in batches
    ranked_queries = sort_by_score_descending(query_scores)

    // 5. Fetch full post content once
    new_post = database.get_post_by_id(new_post_id)

    // 6. Process in batches of 20 queries
    BATCH_SIZE = 20
    for batch_start in range(0, len(ranked_queries), BATCH_SIZE):
        batch = ranked_queries[batch_start : batch_start + BATCH_SIZE]

        try:
            // Call LLM once to evaluate post against all queries in batch
            batch_scores = llm_evaluate_post_against_queries(batch, new_post)
            // Returns: [(query_id, llm_score), ...]

            // 7. Store matches if relevant (score >= 40)
            matches_added = false
            for (query_id, llm_score) in batch_scores:
                if llm_score >= 40:
                    database.insert_query_result(query_id, new_post_id, llm_score)
                    matches_added = true

            if matches_added:
                database.update_last_match_added(query_id)

        catch (error):
            // LLM failed for this batch, fall back to RAG scores
            log_warning("LLM batch evaluation failed, using RAG-only results: " + error.message)

            for (query_id, query, rag_score) in batch:
                if rag_score >= 0.4:  // Equivalent to 40/100
                    database.insert_query_result(query_id, new_post_id, rag_score * 100)

            database.update_last_match_added(query_id)
```

## Server: Initial Query Population (NEW)

**Called when**: A new query is created

```
function populate_initial_query_results(query_id: int):
    // This is the original search logic, now used only for new queries

    query_post = database.get_post_by_id(query_id)
    if not query_post:
        return error("Query post not found")

    // STAGE 1: RAG SEMANTIC SEARCH (Fragment-to-Fragment Matching)

    // 1. Load query embeddings from disk (already computed when query was created/edited)
    query_embeddings = load_embeddings_from_disk(query_post_id)
    // Shape: (num_query_fragments, 768)
    // Typically ~11 fragments for a query with title, summary, and multiple body sentences

    // 2. Load all post embeddings from disk
    all_embeddings = []
    index = []  // Maps (post_id, fragment_idx) to array position

    for each file in "data/embeddings/post_*.npy":
        post_id = extract_id_from_filename(file)
        embeddings = load_numpy_array(file)  // Shape: (num_fragments, 768)

        for frag_idx in 0..num_fragments:
            index.append((post_id, frag_idx))
            all_embeddings.append(embeddings[frag_idx])

    all_embeddings = stack(all_embeddings)  // Shape: (total_fragments, 768)

    // 3. GPU-accelerated similarity matrix computation
    // Compute ALL query fragments × ALL post fragments similarities
    similarity_matrix = compute_similarity_matrix_gpu(query_embeddings, all_embeddings)
    // Shape: (num_query_fragments, total_fragments)
    // Where similarity_matrix[i,j] = cosine similarity between query fragment i and post fragment j

    // 4. Group by post and aggregate scores
    post_similarities = {}  // Collect all similarities for each post

    for i in 0..len(all_embeddings):
        (post_id, frag_idx) = index[i]

        if post_id == query_post_id:
            continue  // Skip the query post itself

        // Get similarities between ALL query fragments and this post fragment
        fragment_sims = similarity_matrix[:, i]  // All query frags vs this post frag

        if post_id not in post_similarities:
            post_similarities[post_id] = []
        post_similarities[post_id].extend(fragment_sims)

    // 5. Compute final post scores using MAX aggregation
    post_scores = {}
    for post_id, sims in post_similarities.items():
        // Primary method: MAX - take best match across all fragment pairs
        post_scores[post_id] = max(sims)

        // Alternative aggregations (logged for analysis):
        // - average: mean(sims)
        // - median: median(sims)
        // - top3_avg: mean of top 3 similarities

    // 5. Get top 20 candidates for LLM refinement
    ranked = sort_by_score_descending(post_scores)
    rag_candidates = ranked[0:20]  // Always get top 20 for LLM processing

    // STAGE 2: LLM POST-PROCESSING (with fault tolerance)

    // 6. Fetch full post content for candidates
    candidate_posts = []
    for (post_id, rag_score) in rag_candidates:
        post = database.get_post_by_id(post_id)
        if post and post.template_name != 'query':  // Exclude query posts
            candidate_posts.append({
                "id": post_id,
                "title": post.title,
                "summary": post.summary,
                "body": post.body,
                "rag_score": rag_score
            })

    // 7. Try to call Claude API to re-rank and filter (fault tolerant)
    try:
        llm_results = llm_rerank_posts(query_post, candidate_posts)

        // 8. Store results in database and return
        for (post_id, llm_score) in llm_results:
            if llm_score >= 40:
                database.insert_query_result(query_id, post_id, llm_score)

    catch (error):
        // LLM failed (API down, out of credits, etc.) - fall back to RAG results
        log_warning("LLM post-processing failed, using RAG-only results: " + error.message)

        // Store RAG results in database
        for post in candidate_posts:
            database.insert_query_result(query_id, post.id, post.rag_score * 100)
```

## Server: Search Endpoint (NEW - Cached Results)

**Endpoint**: `GET /api/search?query_id={query_post_id}&user_email={email}`

**Response**: Array of SearchResult objects (IDs only, client fetches full posts)

```
function get_cached_search_results(query_id: int, user_email: string):
    // 1. Read results from cache
    results = database.get_query_results(query_id)
    // Returns [(post_id, relevance_score, matched_at), ...]
    // Sorted by relevance_score descending

    // 2. Record that this user viewed this query
    if user_email:
        database.record_query_view(user_email, query_id)

    // 3. Return just IDs and scores
    return [{"id": post_id, "relevance_score": score/100} for (post_id, score, _) in results]
```

## Server: Badge Polling Endpoint (NEW)

**Endpoint**: `POST /api/queries/badges`

**Request body**: `{"user_email": "user@example.com", "query_ids": [30, 31, 32, 35]}`

**Response**: `{"30": true, "31": false, "32": true, "35": false}`

```
function get_query_badges(user_email: string, query_ids: [int]) -> {string: bool}:
    // Get badge state for multiple queries for a specific user
    badges = database.get_has_new_matches_bulk(user_email, query_ids)
    // Returns {query_id: has_new_matches}

    // Convert int keys to strings for JSON
    return {string(id): value for id, value in badges}
```

## Server: Database Functions (NEW)

```
function get_posts_by_template(template_name: string) -> [Post]:
    sql = "SELECT * FROM posts WHERE template_name = %s"
    return execute_query(sql, [template_name])

function insert_query_result(query_id: int, post_id: int, score: float):
    // Use ON CONFLICT to update existing matches
    sql = """
        INSERT INTO query_results (query_id, post_id, relevance_score, matched_at)
        VALUES (%s, %s, %s, NOW())
        ON CONFLICT (query_id, post_id)
        DO UPDATE SET relevance_score = %s, matched_at = NOW()
    """
    execute_update(sql, [query_id, post_id, score, score])

function update_last_match_added(query_id: int):
    sql = "UPDATE posts SET last_match_added_at = CURRENT_TIMESTAMP WHERE id = %s"
    execute_update(sql, [query_id])

function record_query_view(user_email: string, query_id: int):
    // Record that a user viewed a query's results (upsert)
    sql = """
        INSERT INTO query_views (query_id, user_email, last_viewed_at)
        VALUES (%s, %s, CURRENT_TIMESTAMP)
        ON CONFLICT (query_id, user_email)
        DO UPDATE SET last_viewed_at = CURRENT_TIMESTAMP
    """
    execute_update(sql, [query_id, user_email])

function get_has_new_matches_bulk(user_email: string, query_ids: [int]) -> {int: bool}:
    // Get badge state for multiple queries for a specific user
    // Returns true if last_match_added_at > last_viewed_at (or never viewed)
    sql = """
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
    """
    results = execute_query(sql, [user_email, query_ids])
    return {row[0]: row[1] for row in results}

function get_query_results(query_id: int) -> [(int, float, timestamp)]:
    sql = """
        SELECT post_id, relevance_score, matched_at
        FROM query_results
        WHERE query_id = %s
        ORDER BY relevance_score DESC
    """
    return execute_query(sql, [query_id])
```

## Server: GPU Similarity Matrix Computation

```
function compute_similarity_matrix_gpu(query_embeddings, all_embeddings):
    // Compute cosine similarity matrix on GPU
    // Args:
    //   query_embeddings: (num_query_fragments, 768)
    //   all_embeddings: (total_fragments, 768)
    // Returns:
    //   similarity_matrix: (num_query_fragments, total_fragments)

    device = "mps" if gpu_available else "cpu"  // Use Metal Performance Shaders on M2

    // Convert to GPU tensors
    query_tensor = to_gpu_tensor(query_embeddings, device)
    all_tensor = to_gpu_tensor(all_embeddings, device)

    // Normalize for cosine similarity
    query_norm = normalize(query_tensor, dim=1)  // L2 normalize each row
    all_norm = normalize(all_tensor, dim=1)

    // Matrix multiplication: (num_query_frags, 768) @ (768, total_frags)
    similarity_matrix = matrix_multiply(query_norm, transpose(all_norm))

    return to_cpu_numpy(similarity_matrix)
```

## Server: LLM Re-ranking Function (UPDATED)

```
// Updated to work with batch of posts for initial query population
function llm_rerank_posts(query_post: Post, posts: [PostCandidate]) -> [(int, int)]:
    // Build prompt for Claude API
    query_text = query_post.title + " " + query_post.summary + " " + query_post.body
    prompt = build_reranking_prompt(query_text, posts)

    // Call Claude API (using Haiku for speed and cost efficiency)
    response = anthropic.messages.create(
        model="claude-3-5-haiku-20241022",
        max_tokens=2000,
        temperature=0.0,  // Deterministic for consistent scoring
        messages=[{
            "role": "user",
            "content": prompt
        }]
    )

    // Parse response to extract scores
    // Expected format: JSON array of {"id": int, "score": int}
    scores = parse_json(response.content[0].text)

    // Sort by LLM score descending
    ranked_results = sort_by_score_descending(scores)

    return [(item.id, item.score) for item in ranked_results]

// New function for batched post-to-queries evaluation (used in background matching)
function llm_evaluate_post_against_queries(query_batch: [(int, Post, float)], new_post: Post) -> [(int, int)]:
    // Build prompt with all queries in batch
    prompt = """You are a semantic search relevance evaluator. Below are search queries from users looking for specific content.

"""

    for (query_id, query_post, rag_score) in query_batch:
        query_text = query_post.title + " " + query_post.summary + " " + query_post.body
        prompt += f"Query {query_id}: {query_text}\n\n"

    prompt += f"""A new post has just been created:
Title: {new_post.title}
Summary: {new_post.summary}
Body: {new_post.body}

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

    response = anthropic.messages.create(
        model="claude-3-5-haiku-20241022",
        max_tokens=1000,
        temperature=0.0,
        messages=[{"role": "user", "content": prompt}]
    )

    // Parse response to extract scores
    scores = parse_json(response.content[0].text)
    return [(item.query_id, item.score) for item in scores]

function build_reranking_prompt(query: string, posts: [PostCandidate]) -> string:
    prompt = """You are a semantic search relevance evaluator. Given a search query and a list of posts, score each post's relevance to the query from 0-100.

Query: "{query}"

Posts to evaluate:
"""

    for i, post in enumerate(posts):
        prompt += f"""
Post {i+1} (ID: {post.id}):
Title: {post.title}
Summary: {post.summary}
Body: {post.body}
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

    return prompt
```

## Server: Database - Add child_count to get_post_by_id

**Critical fix**: The `/api/posts/{id}` endpoint must include `child_count` so search results display navigate-to-children arrows.

```sql
SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
       p.created_at, p.timezone, p.location_tag, p.ai_generated, p.template_name,
       t.placeholder_title, t.placeholder_summary, t.placeholder_body,
       COALESCE(u.name, u.email) as author_name,
       u.email as author_email,
       (SELECT COUNT(*) FROM posts WHERE parent_id = p.id) as child_count
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN templates t ON p.template_name = t.name
WHERE p.id = %s
```

## Client: Badge Polling System

**Polling interval**: 5 seconds

```
function PostsListView(queries: [Post]):
    state badgeStates: {int: bool} = {}  // Map query ID -> badge visibility
    state pollingTimer: Timer = null

    function pollQueryBadges():
        // Only poll if we have queries
        queryIds = [query.id for query in queries if query.template == "query"]
        if queryIds.isEmpty:
            return

        userEmail = Storage.getLoginState().email
        if not userEmail:
            return

        // Call badge endpoint
        request = POST("/api/queries/badges", {
            "user_email": userEmail,
            "query_ids": queryIds
        })

        response = await_response(request)
        // Response: {"30": true, "31": false, ...}

        // Update badge states (convert string keys back to int)
        for (queryIdStr, hasNewMatches) in response:
            queryId = int(queryIdStr)
            badgeStates[queryId] = hasNewMatches

    on_appear:
        pollQueryBadges()  // Poll immediately
        pollingTimer = Timer.repeat_every(5.0, pollQueryBadges)

    on_disappear:
        pollingTimer.invalidate()

    render:
        for query in queries:
            PostView(
                post=query,
                showNotificationBadge=badgeStates[query.id] ?? false
            )
```

## Client: UI Components

### FloatingSearchBar Component

**State management**:
- `isExpanded`: bool - controls collapsed (button) vs expanded (full bar) state
- `isFocused`: FocusState binding - shared with parent for keyboard dismissal

**Visual specs - Collapsed**:
- Circular button: 48pt x 48pt
- Background: Color(white: 0.05) - almost black
- Shadow: black 30% opacity, radius 8pt, y-offset 4pt
- Icon: magnifying glass, white, 20pt font
- Position: 20pt from left edge, 4pt from bottom
- Alignment: leading (left-aligned)

**Visual specs - Expanded**:
- Background: Color(white: 0.05) - almost black
- Corner radius: 25pt
- Shadow: black 30% opacity, radius 8pt, y-offset 4pt
- Horizontal padding: 16pt
- Vertical padding: 12pt
- Bottom padding: 4pt from screen edge
- Max width: 600pt
- Icon: magnifying glass, white 60% opacity, 18pt font
- Text: white with white cursor
- Placeholder: white 60% opacity

**Behavior**:
- **Expand**: Tapping collapsed button animates expansion with spring animation (response: 0.3, dampingFraction: 0.7), auto-focuses text field after 0.1s delay
- **Collapse**: When keyboard dismissed (focus lost) and text is empty, animates collapse with spring animation
- **Debounce**: Search executes 0.5 seconds after last keystroke
- **Clear button**: Appears when text non-empty, clears text, calls onClear(), unfocuses field
- **Animation**: Scale transition from .bottomLeading anchor combined with opacity

### SearchResultsView Component

```
function SearchResultsView(postIds: [int], onPostCreated: callback):
    state posts: [Post] = []
    state isLoading: bool = true

    function fetchPosts():
        if postIds is empty:
            posts = []
            isLoading = false
            return

        fetchedPosts = []
        for postId in postIds:
            response = fetch("http://185.96.221.52:8080/api/posts/{postId}")
            post = decode_json(response.body).post
            fetchedPosts.append(post)

        // Preserve search result ordering
        posts = sort_by_original_order(fetchedPosts, postIds)
        isLoading = false

    on_appear: fetchPosts()
    on_change(postIds): fetchPosts()

    render PostsView(initialPosts=posts, onPostCreated, showAddButton=false)
```

## Client: Integration

```
function NoobTestApp:
    state searchText: string = ""
    state searchResultIds: [int] = []
    state isSearching: bool = false
    focusState isSearchFieldFocused: bool = false  // @FocusState for keyboard control

    function performSearch(query: string):
        if query is empty: return

        isSearching = true

        url = "http://185.96.221.52:8080/api/search?q={url_encode(query)}&limit=20"
        response = fetch(url)
        results = decode_json(response.body)  // [{id: int, relevance_score: float}, ...]

        searchResultIds = extract_ids(results)

    render:
        ZStack:
            // Main content - keep both views alive to preserve navigation state
            ZStack:
                PostsView(initialPosts=posts, onPostCreated=fetchRecentUsers, showAddButton=false)
                    .opacity(isSearching ? 0 : 1)
                    .allowsHitTesting(!isSearching)

                if isSearching:
                    SearchResultsView(postIds=searchResultIds, onPostCreated=fetchRecentUsers)

                // Invisible overlay for keyboard dismissal - only when keyboard visible
                if isSearchFieldFocused:
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { isSearchFieldFocused = false }

            // Floating search bar overlay
            VStack:
                Spacer()
                FloatingSearchBar(
                    searchText=searchText,
                    isFocused=isSearchFieldFocused,  // Binding to FocusState
                    onSearch=performSearch,
                    onClear={ isSearching = false; searchResultIds = [] }
                )
```

## Patching Instructions

### Server (Python) - Database Changes

1. **db.py**:
   - Add `last_match_added_at TIMESTAMP` column to posts table (migration)
   - Create new `query_results` table with schema above
   - Create new `query_views` table for per-user view tracking
   - Add database functions: `get_posts_by_template()`, `insert_query_result()`, `update_last_match_added()`, `record_query_view()`, `get_has_new_matches_bulk()`, `get_query_results()`

### Server (Python) - Search Logic Changes

2. **app.py**:
   - Update `/api/search` endpoint to accept `user_email` parameter and call `record_query_view()`
   - Add new `/api/queries/badges` POST endpoint for bulk badge checking
   - Add background matching: hook into post creation to call `check_post_against_queries(new_post_id)`
   - Add initial query population: when query created, call `populate_initial_query_results(query_id)`
   - Update `check_post_against_queries()` to call `update_last_match_added()` when matches added
   - Update `populate_initial_query_results()` to call `update_last_match_added()` when results stored

### Client (iOS) - UI Changes

3. **PostsListView.swift**:
   - Add `badgeStates: [Int: Bool]` state to track badge visibility per post
   - Add `pollingTimer: Timer?` for regular badge polling
   - Add `pollQueryBadges()` function to call `/api/queries/badges` endpoint
   - Start polling on appear (immediate + every 5 seconds)
   - Stop polling on disappear
   - Pass `showNotificationBadge: badgeStates[post.id] ?? false` to PostView

4. **PostView.swift**:
   - Accept `showNotificationBadge: Bool` parameter (passed from parent)
   - Display 8pt red circle badge when `showNotificationBadge == true`
   - Position badge 8pt from top-right corner using `.overlay(alignment: .topTrailing)`

5. **PostsView.swift** (QueryResultsViewWrapper):
   - Update `/api/search` call to include `&user_email={email}` parameter
   - Get user email from `Storage.shared.getLoginState().email`
   - URL-encode email before adding to query string

### Key Architecture Changes

**From**: On-demand search (slow, 5-7 seconds)
- User taps query → server searches all posts → LLM ranks → return results

**To**: Background matching (instant)
- New post created → server checks against all queries → stores matches
- User taps query → server reads from cache → instant results
- Badge shows when new matches available
