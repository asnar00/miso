# expand-and-scroll pseudocode

## State Management

```
state expandedPostId: PostId? = null
```

Only one post can be expanded at a time. Each PostView controls its own `expansionFactor`, but the list coordinates which post should be expanded.

## Expansion Logic

```
when post tapped:
  previousExpandedId = expandedPostId

  if post.id == expandedPostId:
    // Tapping the currently expanded post - collapse it
    expandedPostId = null
  else:
    // Expanding a different post
    expandedPostId = post.id

    // Scroll to new expanded post concurrently with animation
    animate scroll to post.id with anchor=top, duration=0.3s, easing=easeInOut
```

Each PostView observes `expandedPostId` and sets its own target `expansionFactor`:
```
if expandedPostId == this.post.id:
  targetExpansionFactor = 1.0
else:
  targetExpansionFactor = 0.0

animate expansionFactor to targetExpansionFactor over 0.3s with easeInOut
```

**Key decision**: All animations (previous post collapse, new post expand, scroll to position) happen **concurrently** over the same 0.3-second duration with the same easing curve for visual coherence.

## Scroll-to-Expanded on Navigation Return

```
on view appear:
  if expandedPostId not null:
    delay 0.1 seconds:  // ensure view is laid out
      animate scroll to expandedPostId with anchor=top
```

When returning from navigation (e.g., after viewing children), scroll back to the expanded post so the user doesn't lose their place.

## Initial State

```
on posts loaded:
  if posts not empty:
    expandedPostId = posts[0].id  // expand first post by default
```
