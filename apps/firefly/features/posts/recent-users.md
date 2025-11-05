# recent users
*fetch and display users sorted by most recent activity*

When you open Firefly after signing in, the app automatically fetches users from the server and displays them as a list of profile posts, ordered by most recent activity.

Users are sorted by their last_activity timestamp (most recent first), so the most recently active user appears at the top of the list.

**What you see:**

Each user is shown as their profile post (the post with parent_id = -1). The profile shows the user's name, summary, and profile image if they have one.

**Loading behavior:**

- On app open (after sign-in), immediately fetch recent users
- Show a turquoise background (RGB 64/224/208) with a black "ᕦ(ツ)ᕤ" logo (1/12 screen width) above a "Loading users..." message
- Once users are fetched, preload the first profile image before displaying the list
- Continue loading remaining images in the background
- If fetching fails, show an error message with a retry button on the turquoise background

**No "Add Post" button**: Unlike the recent-posts view, this view doesn't show an "Add Post" button. Users can navigate to individual profiles to see their posts.

All profiles start in compact view. Tap any profile to expand it and read the full profile description. Swipe left on a profile (or tap the navigation button) to see all posts by that user.
