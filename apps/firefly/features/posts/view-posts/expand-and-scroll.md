# expand and scroll
*smooth post expansion with automatic repositioning*

When you tap on a compact-form post view to expand it, three things happen in parallel, over 0.3 seconds:

- the previously expanded post (if any) collapses to compact form
- the new post expands from collapsed to expanded form
- the display scrolls so the top edge of the new post aligns with the top edge of the display.

To compute the target scroll offset, we need to figure out the scroll offset based on the index of the post we're expanding in the list, and the height of compact posts (plus any other buttons such add/remove/search).

