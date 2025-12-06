# toolbar
*a sleek rounded button strip, always present*

The `toolbar` is a sleek rounded lozenge at the bottom of the screen; it floats above the content with a subtle shadow, creating a modern, polished appearance.

**Visual Design:**
- Rounded lozenge shape (20pt corner radius)
- Background color: tunable button color (RGB 255/178/127 modified by brightness, default 1.0)
- Maximum width of 300pt, centered on screen
- Strong shadow for depth (40% black opacity, 12pt blur, 4pt downward offset)
- Positioned 20pt offset from safe area bottom
- Color matches all other UI buttons (add-post button, author button, child navigation button, edit button)

**Button Sizing:**
- Icons: 20pt font size
- Button frames: 35x35pt with 6pt corner radius
- Horizontal padding: 33pt
- Vertical padding: 10pt

The toolbar has three buttons:

- **"make post"** (speech bubble icon) : shows all recent posts from all users, with an "add post" button at the top

- **"search"** (magnifying glass icon) : shows all users' saved searches, with a "new search" button at the top

- **"users"** (two people icon) : shows a list of all users in the system, with an "invite friend" button at the top

**Button Text Convention**: All action buttons use lowercase text (e.g., "add post", "new search", "add sub-post", "invite friend", "add image").

Each button highlights when active with a darker background (80% of standard button color brightness) for clear visual feedback.

**State Persistence**: When you switch between explorers, each view remembers its navigation state - scroll position, which posts are expanded, and where you were in the hierarchy. Switching back returns you exactly where you left off.

**Reset Behavior**: Tapping the currently active toolbar button resets that explorer back to its initial state - clearing navigation history and returning to the top-level view.

**Visibility During Editing**: The toolbar fades out (0.3s animation) and becomes non-interactive when editing any post. It reappears when editing ends (save, cancel, or delete) or when navigating back from a child view.

**Search Notification Badge**: When any of the user's saved searches has new matches, a red notification dot (10pt diameter with 2pt white outline) appears at the top-right corner of the search button. This badge is polled every 5 seconds and also checked immediately when searches are loaded at startup.
