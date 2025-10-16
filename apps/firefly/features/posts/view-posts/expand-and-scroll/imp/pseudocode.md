# expand-and-scroll pseudocode

## State Management

```
state expandedPostIds: Set<PostId> = empty
```

Only one post can be expanded at a time (enforced by clearing the set before adding).

## Expansion Logic

```
when post tapped for expansion:
  collapse all posts:
    expandedPostIds.clear()

  expand this post:
    expandedPostIds.add(post.id)

  scroll to post concurrently:
    animate scroll to post.id with anchor=top, duration=0.3s, easing=easeInOut
```

**Key decision**: All three animations (old post collapse, new post expand, scroll to position) happen **concurrently** over the same 0.3-second duration with the same easing curve for visual coherence.

## Collapse Animation Sequence

When collapsing (tap on expanded post):

```
state isAnimatingCollapse: Bool = false
state collapseHeight: Float? = nil

on collapse triggered:
  isAnimatingCollapse = true
  collapseHeight = nil  // starts at full height

  animate over 0.3s with easeInOut:
    collapseHeight = measuredCompactHeight

  after 0.3s:
    isAnimatingCollapse = false
    collapseHeight = nil  // reset for next time
```

## View Selection During Animation

```
if isExpanded or isAnimatingCollapse:
  render fullView with:
    fixedSize(horizontal=false, vertical=true)  // prevent content reflow
    frame(height=collapseHeight, alignment=top)  // clip from bottom
    clipped()  // apply clipping
else:
  render compactView
```

**Key decision**: Use `fixedSize` + `frame(alignment: .top)` + `clipped()` to keep content layout frozen and clip from the bottom, avoiding janky content rearrangement during the collapse animation.

## First Post Auto-Expansion

```
on posts loaded successfully:
  if posts not empty:
    expandedPostIds.add(posts[0].id)
```

Automatically expands the first post when posts are initially loaded.
