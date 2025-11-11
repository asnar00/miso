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
```

## Server: Search Endpoint

**Endpoint**: `GET /api/search?q={query}&limit={limit}`

**Response**: Array of SearchResult objects (IDs only, client fetches full posts)

```
function search_posts(query: string, limit: int = 20):
    // 1. Load all embeddings from disk
    all_embeddings = []
    index = []  // Maps (post_id, fragment_idx) to array position

    for each file in "data/embeddings/post_*.npy":
        post_id = extract_id_from_filename(file)
        embeddings = load_numpy_array(file)  // Shape: (num_fragments, 768)

        for frag_idx in 0..num_fragments:
            index.append((post_id, frag_idx))
            all_embeddings.append(embeddings[frag_idx])

    all_embeddings = stack(all_embeddings)  // Shape: (total_fragments, 768)

    // 2. Generate query embedding
    model = get_sentence_transformer("all-mpnet-base-v2")
    query_emb = model.encode(query)  // Shape: (768,)

    // 3. GPU-accelerated similarity computation
    query_tensor = to_gpu_tensor(query_emb)  // Shape: (1, 768)
    all_tensor = to_gpu_tensor(all_embeddings)  // Shape: (N, 768)
    scores = cosine_similarity(query_tensor, all_tensor)  // Shape: (N,)

    // 4. Group by post and take max score per post
    post_scores = {}
    for i in 0..len(scores):
        (post_id, frag_idx) = index[i]
        if post_id not in post_scores:
            post_scores[post_id] = scores[i]
        else:
            post_scores[post_id] = max(post_scores[post_id], scores[i])

    // 5. Sort and limit
    ranked = sort_by_score_descending(post_scores)
    top_results = ranked[0:limit]

    // 6. Return just IDs and scores
    return [{"id": post_id, "relevance_score": score} for (post_id, score) in top_results]
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

### Server (Python)

1. **app.py**: Add search endpoint after existing routes
2. **db.py**: Update `get_post_by_id()` to include child_count subquery
3. **embeddings.py**: Add module for sentence transformer model management
4. **generate_all_embeddings.py**: Utility to pre-generate embeddings for all posts

### Client (iOS)

1. **FloatingSearchBar.swift**: New file - search bar UI component
2. **SearchResultsView.swift**: New file - displays search results by fetching posts by ID
3. **NoobTestApp.swift**: Add search state variables, integrate FloatingSearchBar in ZStack overlay
4. **Post.swift**: Ensure `childCount` field mapped from `child_count` (already exists)

### Key Design Decision

**Why return IDs not full posts?**
- Search endpoint returns minimal data: just post IDs and relevance scores
- Client fetches full post data using existing `/api/posts/{id}` endpoint
- This ensures search results have ALL fields (including child_count) that regular posts have
- Maintains consistency: search results and regular posts use same data source
- Avoids duplicating post serialization logic in search endpoint
