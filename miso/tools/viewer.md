# viewer
*navigate and view snippet trees*

The viewer is a simple application panel that sits on the left of the screen, and allows the user to view snippets and navigate through the tree.

It shows navigation breadcrumbs (the current path, clickable), then the content (rendered as preview markdown to github standard), and finally a list of clickable child snippets (a title and one-line summary for each).

If the content is longer than the size of the window, the user should be able to scroll down and back up.

If the user asks to `view A/B/C`, the viewer should be sent a message that causes it to jump to the snippet `A/B/C`.