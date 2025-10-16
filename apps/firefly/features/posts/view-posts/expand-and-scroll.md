# expand and scroll
*smooth post expansion with automatic repositioning*

When you tap on a post to expand it, two things happen at once: the currently expanded post smoothly shrinks down to its compact form, while the post you tapped grows to show its full content, while aligning to the top of the phone's screen so you can read it.

To make this happen smoothly, the app first computes the eventual scroll offset of the top of the new post - this is simply the index of the expanding post in the list, multiplied by the padded height of compact views (which are always the same height).

The app then kicks off three animations simultaneously: the old post compacts to compact-view size, the new post expands to full size, and scrolling smoothly travels to the computed scroll offset.

Once the old post has been compacted to the right size, it gets swapped out for a compact view and nobody's the wiser.