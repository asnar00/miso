# explore tree
*how we navigate around trees of posts*

If a post has children, the post view draws a "rightward link". This is rendered as a small circle intersecting the right edge of the post view; extending rightwards offscreen. The link is drawn to line up with the center-line of the post view's thumbnail when compacted; and maintains this position during expansion.

If the user drags such a post to the left (while expanded or compacted), we scroll leftwards to a view of its list of children.

Similarly, if a post has a parent, then we draw a "leftward link" from the left edge of the post view; again, a small circle intersecting the left edge, extending off the left edge of the screen.

If we drag such a post-view rightwards, then we navigate "back" to the parent.

