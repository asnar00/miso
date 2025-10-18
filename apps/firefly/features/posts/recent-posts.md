# recent posts
*fetch and display the 50 most recently created posts*

When you open Firefly after signing in, the app automatically fetches the 50 most recent posts from the server and displays them using the view-posts component.

The posts are sorted by creation date, newest first, so the most recent post appears at the top of the feed.

**Loading behavior:**

- On app open (after sign-in), immediately fetch recent posts
- Show a loading spinner while the request is in progress
- Once posts are fetched, preload the first image before displaying the feed
- Continue loading remaining images in the background
- If fetching fails, show an error message with a retry button

All posts start in compact view. Tap any post to expand it and read the full content.
