# search UI
*floating search bar overlay for semantic post search*

A floating search bar that appears at the bottom of the screen as an always-visible overlay. Users can tap to enter search queries and see results displayed in the posts list.

**Visual design**:
- Rounded rectangle "lozenge" shape
- Positioned at bottom center of screen
- Floats above all other content (overlay layer)
- Search icon (magnifying glass) on the left
- Text input field fills the rest
- Subtle shadow for depth

**Behavior**:
- Always visible regardless of scroll position
- Tapping activates the text field for input
- As user types, search query is sent to server (debounced)
- Results replace current post list view
- Clearing search returns to previous view

**Layout**:
- Width: 90% of screen width, max 600pt
- Height: 50pt
- Bottom margin: 20pt from screen bottom
- Corner radius: 25pt (fully rounded ends)
- Background: semi-transparent white/dark with blur effect
- Shadow: subtle elevation shadow

**Search flow**:
1. User taps search bar
2. Keyboard appears, user types query
3. After 0.5s debounce, send query to `/api/search?q=query`
4. Display results in PostsListView
5. Clear button (X) clears query and returns to recent posts
