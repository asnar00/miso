# recent posts
*fetch and display the 50 most recently created posts*

This view fetches the 50 most recent posts from the server and displays them using the view-posts component.

**Note**: The app now starts with the recent-users view instead of recent-posts. Users can navigate to recent-posts if needed.

The posts are sorted by creation date, newest first, so the most recent post appears at the top of the feed.

**Loading behavior:**

- On app open (after sign-in), immediately fetch recent posts
- Show a turquoise background (RGB 64/224/208) with a black "ᕦ(ツ)ᕤ" logo (1/12 screen width) above a "Loading posts..." message
- Once posts are fetched, preload the first image before displaying the feed
- Continue loading remaining images in the background
- If fetching fails, show an error message with a retry button on the turquoise background

All posts start in compact view. Tap any post to expand it and read the full content.
