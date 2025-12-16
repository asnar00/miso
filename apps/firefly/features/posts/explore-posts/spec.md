# explore posts
*navigate through the tree of posts and their children*

Posts can have children, forming a tree structure. Users can navigate into child posts to explore deeper levels of the conversation.

**Visual Indicator**: Posts with children show a circular button (RGB color where R=G=B="button-colour" tunable, default 0.5) with a black chevron arrow (pointing right). The button has a subtle shadow that gives it depth. When you tap on a post to expand it, the button smoothly animates: it grows slightly larger and moves from the right edge to the top right corner. When you collapse the post, it animates back to its original position. The animation is smooth and matches the card's expansion. The button color matches all other UI buttons (add-post button, toolbar, author button) for visual consistency.

**Add Child Post**: When viewing any post that has zero children, the circular button shows a "+" icon instead of a chevron. Tapping this button navigates to an empty children view showing "No posts yet" with an add button. The user must tap the button to create the first child post. Anyone can add a child post to any post, except for profile posts where only the profile owner can add children.

**Navigate to Children**: Swipe left on a post with children (at least 30 points of movement) to navigate to a view showing all its child posts.

**Child Posts View**: Shows the child posts. The navigation bar displays a custom back button on the left side, showing a chevron arrow and the parent post's title (e.g., "< test post").

**Add Post Button**: The add button (using standard button color, lowercase text) appears at the top of child post lists, allowing users to add additional children. The button text depends on the parent post's template: "add post" for profile children, "add sub-post" for all other post types. Anyone can add children to any post, except for profile posts where only the profile owner sees the button. The button color matches all other UI buttons for visual consistency.

**Navigate Back**: Tap the back button to return to the parent view.

**Scroll Position Preserved**: When you navigate from the main posts list to view children, then return, your scroll position is preserved exactly where you left it.

**Expansion Effects**: When a post expands, it receives visual emphasis through animated effects:
- **Brightness**: The post background brightens to 120% of base brightness (clamped to 1.0), smoothly animating with the expansion
- **Drop Shadow**: A shadow appears below the expanded post (radius: 2→16pt, offset: 0→16pt, opacity: 0.2→0.5), creating a 3D "popping up" effect
- **Z-Ordering**: Expanded posts render above collapsed posts to ensure shadows display correctly over neighboring posts

**Multiple Levels**: You can navigate through multiple levels of the post tree. Each level shows its own back button with the parent's title.