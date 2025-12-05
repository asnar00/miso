# post view
*how a single post is displayed*

A post is displayed using a *post view*, which can take two forms, *compact* and *expanded*

In compact form, we see a lozenge almost as wide as the phone screen, about 1/6th the height of the screen. The post view's width adapts to the screen size: the right edge of the post is at (screen width - horizontal padding), where horizontal padding is determined by the parent list view. The view displays the title (in 24pt bold) and the one-line summary below it (in smaller italics). Finally, below that is the name of the author, followed by the date (formatted as "day monthname year", e.g., "5 Nov 2025"), in even smaller text with 16pt spacing between them. The author bar font size is scaled by the "author-font-size" tunable (default 1.0) in addition to the global font-scale. All text wraps around, leaving space for a square thumbnail on the right-hand-side of the view (centered vertically within the lozenge, and inset from the right edge by a small padding).

**Author navigation**: The author name appears as a rounded lozenge button (RGB color where R=G=B="button-colour" tunable, default 0.5) with black text when the author has a profile with content (non-empty title or summary). Tapping it fetches the author's profile and displays it in a new view, with the current post's title as the back button label. If the author doesn't have a profile with content, or if this is a profile post itself (where template is "profile"), the author name shows as plain grey text (50% opacity) instead of a button. The button color matches all other UI buttons (add-post button, toolbar, child navigation button) for visual consistency.

In expanded form, the title and summary display exactly as in the compact version; below them is the image, then below that the body text; and then below that the author name and date. For posts you own, an edit button (pencil icon, 32pt) appears aligned with the post's right edge. The edit controls (save/cancel/delete buttons) also right-align with the post's right edge.

**Navigate-to-children button**: Posts with children (or query posts) show a circular button on the right side. This button is positioned so that 3/4 of its radius overlaps the post view (i.e., 1/4 of the button extends beyond the right edge). The button is vertically centered within the post view.

To animate from compact to expanded, we animate the thumbnail so that it moves and rescales to the eventual full-size / aligned position of the full-size image; the author/datestamp information moves downwards to stick to the bottom of the view boundary; and the body text clips into its eventual place. The reverse animation happens in the same way, but ... in reverse.

This creates clear continuity between the compact and expanded forms, reducing visual confusion for users.