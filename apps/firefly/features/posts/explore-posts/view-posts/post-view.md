# post view
*how a single post is displayed*

A post is displayed using a *post view*, which can take two forms, *compact* and *expanded*

In compact form, we see a lozenge almost as wide as the phone screen, about 1/6th the height of the screen. The view displays the title (in 24pt bold) and the one-line summary below it (in smaller italics). Finally, below that is the name of the author and the date/time, in even smaller text. All text wraps around, leaving space for a square thumbnail on the right-hand-side of the view (centered vertically within the lozenge, and inset slightly from the right).

In expanded form, the title and summary display exactly as in the compact version; below them is the image, then below that the body text; and then below that the author/datestamp information.

To animate from compact to expanded, we animate the thumbnail so that it moves and rescales to the eventual full-size / aligned position of the full-size image; the author/datestamp information moves downwards to stick to the bottom of the view boundary; and the body text clips into its eventual place. The reverse animation happens in the same way, but ... in reverse.

This creates clear continuity between the compact and expanded forms, reducing visual confusion for users.