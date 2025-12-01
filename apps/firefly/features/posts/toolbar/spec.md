# toolbar
*a sleek rounded button strip, always present*

The `toolbar` is a sleek rounded lozenge at the bottom of the screen; it floats above the content with a subtle shadow, creating a modern, polished appearance.

**Visual Design:**
- Rounded lozenge shape (25pt corner radius)
- Background color: RGB where R=G=B="button-colour" tunable (default 0.5)
- Maximum width of 300pt, centered on screen
- Strong shadow for depth (40% black opacity, 12pt blur, 4pt downward offset)
- Positioned 12pt from bottom edge, nestled in the screen curve
- Color matches all other UI buttons (add-post button, author button, child navigation button)

The toolbar has three buttons:

- **"make post"** (speech bubble icon) : shows all recent posts from all users, with a "create post" button at the top

- **"search"** (magnifying glass icon) : shows the current user's most recent queries, with a "create query" button at the top

- **"users"** (two people icon) : shows a list of all users in the system

Each button highlights when active with a darker grey background (50% grey opacity) for clear visual feedback.

**State Persistence**: When you switch between explorers, each view remembers its navigation state - scroll position, which posts are expanded, and where you were in the hierarchy. Switching back returns you exactly where you left off.

**Reset Behavior**: Tapping the currently active toolbar button resets that explorer back to its initial state - clearing navigation history and returning to the top-level view.
