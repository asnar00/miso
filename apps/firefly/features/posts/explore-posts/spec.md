# explore posts
*navigate through the tree of posts and their children*

Posts can have children, forming a tree structure. Users can navigate into child posts to explore deeper levels of the conversation.

**Visual Indicator**: Posts with children show a circular button (RGB color where R=G=B="button-colour" tunable, default 0.5) with a black chevron arrow (pointing right). The button has a subtle shadow that gives it depth. When you tap on a post to expand it, the button smoothly animates: it grows slightly larger and moves from the right edge to the top right corner. When you collapse the post, it animates back to its original position. The animation is smooth and matches the card's expansion. The button color matches all other UI buttons (add-post button, toolbar, author button) for visual consistency.

**Add Your Own Child Post**: When viewing your own posts that have zero children, the circular button shows a "+" icon instead of a chevron. Tapping this button navigates to an empty children view and automatically creates a new child post in edit mode, making it quick to add the first child to your post.

**Navigate to Children**: Swipe left on a post with children (at least 30 points of movement) to navigate to a view showing all its child posts.

**Child Posts View**: Shows the child posts. The navigation bar displays a custom back button on the left side, showing a chevron arrow and the parent post's title (e.g., "< test post").

**Add Post Button**: The "Add Post" button (RGB color where R=G=B="button-colour" tunable) appears at the top of child post lists when the parent post is owned by the currently logged-in user. This allows users to add additional children after the first one. For profile posts, the button only appears if the profile belongs to the current user. The button color matches all other UI buttons for visual consistency.

**Navigate Back**: Either tap the back button or swipe right from anywhere on the screen (at least 50 points of horizontal movement) to return to the parent view. The swipe must be more horizontal than vertical to trigger navigation.

**Scroll Position Preserved**: When you navigate from the main posts list to view children, then return, your scroll position is preserved exactly where you left it.

**Multiple Levels**: You can navigate through multiple levels of the post tree. Each level shows its own back button with the parent's title.