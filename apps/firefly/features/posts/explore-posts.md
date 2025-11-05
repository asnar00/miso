# explore posts
*navigate through the tree of posts and their children*

Posts can have children, forming a tree structure. Users can navigate into child posts to explore deeper levels of the conversation.

**Visual Indicator**: Posts with children show a white circular button with a black chevron arrow (pointing right). The button has a subtle shadow that gives it depth. When you tap on a post to expand it, the button smoothly animates: it grows slightly larger and moves from the right edge to the top right corner. When you collapse the post, it animates back to its original position. The animation is smooth and matches the card's expansion.

**Navigate to Children**: Swipe left on a post with children (at least 30 points of movement) to navigate to a view showing all its child posts.

**Child Posts View**: Shows the child posts. The navigation bar displays a custom back button on the left side, showing a chevron arrow and the parent post's title (e.g., "< test post").

**Add Post Button**: When viewing the children of a profile post, the "Add Post" button only appears if the profile belongs to the currently logged-in user. This allows users to add posts to their own profile but not to other users' profiles.

**Navigate Back**: Either tap the back button or swipe right from anywhere on the screen (at least 50 points of horizontal movement) to return to the parent view. The swipe must be more horizontal than vertical to trigger navigation.

**Scroll Position Preserved**: When you navigate from the main posts list to view children, then return, your scroll position is preserved exactly where you left it.

**Multiple Levels**: You can navigate through multiple levels of the post tree. Each level shows its own back button with the parent's title.