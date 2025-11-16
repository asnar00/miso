# search
*semantic search across all posts using fragment-level embeddings*

Users can search for posts using saved queries. Create a query (with title, summary, and details), then tap the circle button on the right to execute it. Matching posts appear in rank order by relevance.

**Query UI**:
- App shows list of user's saved queries (template_name='query')
- Each query is a post with title, summary, and body describing what to search for
- Queries show a circular button (32pt collapsed, 42pt expanded) on the right
- **Tap or swipe left** on a query to execute the search
- Search uses the query's **title** as the search text
- Results appear in a new view with back navigation to return to queries
- **Query filtering**: Queries themselves are excluded from search results (no recursive queries)

**How it works**:
- Each post is split into fragments: title, summary, and body sentences (split on punctuation: .,;:!?)
- Each fragment gets a 768-dimensional vector embedding (all-mpnet-base-v2 model)
- Query is converted to same vector format
- GPU compares query vector against all fragment vectors using cosine similarity
- Posts ranked by their highest-scoring fragment
- Top matches displayed in relevance order

**Search results**:
- Results filtered to exclude query posts (template_name != 'query')
- Posts fetched individually with full data including child counts
- Navigate-to-children arrows (>) appear for posts with children
- All post interactions work normally (expand, edit, view profile, navigate)
- **Back button** labeled with query title returns to queries list

**Creating queries**:
- "Add Query" button at top of queries list
- Create new query post with title (the search text), summary, and details
- Query posts are tagged with template_name='query'
- Queries are root-level posts (parent_id=-1), not children of user's profile
