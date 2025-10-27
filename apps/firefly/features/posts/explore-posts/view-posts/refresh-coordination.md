# refresh coordination
*keeping different views in sync when posts are created*

When you create a new post, all the views that might show that post need to refresh to display it.

This gets tricky when you're deep in the navigation hierarchy. For example, if you're viewing the children of a post and you create a new child, both the children view you're in AND the parent view you came from need to refresh.

To handle this, we pass a refresh callback through the entire view hierarchy. When a post is created anywhere, it triggers refreshes all the way back up to the top level.

This means you always see the latest posts no matter where you create them, and all views stay perfectly in sync.