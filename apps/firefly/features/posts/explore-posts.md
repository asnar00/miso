# explore posts
*let the user explore the tree of posts*

`explore-posts` allows the user to explore the tree of posts by navigating to the child post list of any post in a `view-posts` view.

If a post in `post-view` has one or more children, the post-view displays a right-facing arrow across its right-hand edge.

Swiping such a post towards the left adds a new `view-posts` view to the right hand side, showing all child posts (and an "add post" button at the top); everything then scrolls to the left so that only the child list view is visible.

At any point, dragging the child view to the right will scroll leftwards, exposing the parent list view, until there are no more such views.