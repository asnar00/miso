# create post
*make a new post*

This creates a new post in the database, populated with title, summary, image (if required), and body text. It should also set the author (by email address), and the current timezone, local time, and location.

By default, new posts are created as children of the user's profile post. This ensures all user posts are organized under their profile in the tree structure.

When creating a child post (a post that belongs to another post), you can optionally provide a different parent post's ID to link them together in a different part of the tree structure. If no parent_id is specified, the system automatically sets the parent to the user's profile post (the post with parent_id = -1 for that user).