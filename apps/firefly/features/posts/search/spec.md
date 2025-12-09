# search
*instant cached search results with background matching*

Users can search for posts using saved searches. Create a search (with title, summary, and details), then tap the circle button to see matching posts instantly. The system continuously checks new posts against all searches in the background, so results are pre-computed and ready.

**Search UI**:
- App shows list of all users' saved searches (template_name='query' internally)
- Each search is a post with title, summary, and body describing what to search for
- Searches show a circular button (32pt collapsed, 42pt expanded) on the right
- **Tap or swipe left** on a search to view cached results (instant, no wait)
- Results appear in a new view with back navigation to return to searches list

**Notification Badges** (uses `infrastructure/notifications/spec.md`):
- Red dot badge (12pt diameter, 2pt white outline) on search post card when new matches exist
- Badge positioned 6pt from top and right edges of the post view
- Polling every 5 seconds checks for new matches
- Badge appears when: `last_match_added_at` > user's `last_viewed_at` for that query
- Badge clears when: user views search results (records view timestamp server-side)
- Toolbar search icon also shows badge if ANY query has new matches

**How it works - Background Matching**:
When any new post is created (regular post or query):
- **Stage 1: RAG Semantic Search** (fragment-to-fragment matching)
  - New post is split into fragments: title, summary, and body sentences (split on punctuation: .,;:!?)
  - Each fragment gets a 768-dimensional vector embedding (all-mpnet-base-v2 model)
  - GPU computes similarity against ALL queries in database
  - For each query, compute similarity between all query fragments and new post fragments
  - Queries ranked by maximum similarity score across all fragment pairs (MAX aggregation)
  - Top 20 matching queries selected for LLM refinement

- **Stage 2: LLM Post-Processing** (fault tolerant)
  - For each of the top 20 queries, send query + new post to Claude Haiku API
  - Claude evaluates the post's true relevance to that query
  - Post receives relevance score 0-100 for that query
  - If score >= 40, save match to `query_results` table
  - Update `last_match_added_at` timestamp on query (triggers notification badges)
  - Uses Claude 3.5 Haiku for fast, cost-effective evaluation
  - **Fallback**: If LLM fails (API down, out of credits), uses RAG score only

**When creating a new search**:
- System runs full search against ALL existing posts (may take several seconds)
- Populates initial results in `query_results` table
- User sees "Searching..." indicator during this one-time setup
- After initial search completes, all future results arrive via background matching

**Cached Results Storage**:
- `query_results` table stores (query_id, post_id, relevance_score, matched_at)
- `query_views` table tracks per-user view times (query_id, user_email, last_viewed_at)
- Each query has `last_match_added_at` timestamp (updated when matches added)
- Badge logic: compare `last_match_added_at` vs user's `last_viewed_at` per query
- Tapping search reads from cache (instant) and records view time for that user

**Search results**:
- Results filtered to exclude search posts (template_name != 'query')
- Posts fetched individually with full data including child counts
- Navigate-to-children arrows (>) appear for posts with children
- All post interactions work normally (expand, edit, view profile, navigate)
- **No "add post" button** in search results view (results are read-only display)
- **Back button** labeled with search title returns to searches list

**Creating searches**:
- "new search" button at top of searches list
- Create new search post with title (the search text), summary, and details
- Search posts are tagged with template_name='query' internally
- Searches are root-level posts (parent_id=-1), not children of user's profile
