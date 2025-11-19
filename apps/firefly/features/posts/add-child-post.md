# add child post
*quickly add a child to your own posts*

The circular button on posts dynamically displays either a chevron ">" or a plus "+" symbol depending on the post state.

**Visual Design**: The button is a white circular button with a subtle shadow. It displays either:
- ">" chevron: when the post has children (navigates to children view)
- "+": when the post has zero children AND is owned by the logged-in user (adds a child post)

**Dynamic Switching**: The button icon updates automatically based on the post's child count. When you add the first child and navigate back, the button changes from "+" to ">".

**Add Child Behavior**: When the "+" button is tapped:
1. Navigate to the (empty) children view for this post
2. Automatically create and open a new post in edit mode
3. The new post has this post as its parent

**Show Button Logic**: The button appears when:
- Post has children (shows ">"), OR
- Post has zero children AND is owned by the logged-in user (shows "+")

**Animation**: The button animates smoothly with post expansion - growing slightly and moving to the top right corner when the post expands.
