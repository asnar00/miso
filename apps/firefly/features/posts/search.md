# search
*semantic search across all posts using fragment-level embeddings*

Users can search for posts using natural language queries. A circular search button appears in the bottom left corner. Tap it to expand into a search bar, type your query, and matching posts appear in rank order by relevance.

**Search UI**:
- **Collapsed state**: Circular search button (48pt diameter) in bottom left corner, 20pt from left edge, 4pt from bottom
- **Expanded state**: Tapping button animates expansion to full search bar (max width 600pt)
- **Auto-focus**: Keyboard appears automatically when expanded
- **Auto-collapse**: Tapping outside search field when text is empty collapses back to button
- **Visual design**: Almost-black background (RGB 0.05, 0.05, 0.05) with subtle shadow
- **Search icon**: Light gray (white at 60% opacity) in collapsed state, white in expanded state
- **Text field**: White text with white cursor, light gray placeholder text
- **Clear button**: X icon appears when text is entered, clears text and closes keyboard
- **Debounce**: Search executes 0.5 seconds after user stops typing
- **Navigation preserved**: Switching between search results and normal view maintains your position in the post hierarchy
- **Results display**: All results show with full functionality (expand, navigate to children, view profiles)

**How it works**:
- Each post is split into fragments: title, summary, and body sentences (split on punctuation: .,;:!?)
- Each fragment gets a 768-dimensional vector embedding (all-mpnet-base-v2 model)
- Query is converted to same vector format
- GPU compares query vector against all fragment vectors using cosine similarity
- Posts ranked by their highest-scoring fragment
- Top matches displayed in relevance order

**Search results**:
- Posts fetched individually with full data including child counts
- Navigate-to-children arrows (>) appear for posts with children
- All post interactions work normally (expand, edit, view profile, navigate)
