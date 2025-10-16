# view posts
*display a list of posts in a scrollable feed with images and formatted text*

This component displays any list of posts as a scrolling feed against a bright turquoise background.

Each post appears in a white card with slightly rounded corners and a subtle shadow. The cards are spaced comfortably apart so you can easily tell where one ends and the next begins.

Inside each card:

- The **title** appears at the top in large, bold text
- Below that is the *summary* in smaller italic text
- If the post has an image, it appears next with nicely rounded corners
- The main body text follows, with proper formatting:
  - Headings appear larger and bold
  - Bullet points show as actual bullets (") with proper indentation
  - Paragraphs flow naturally with appropriate spacing
  - Image references in the text are hidden (they'd be redundant since the image is already showing)

At the bottom of each card you'll find:

- Author name or "👓 librarian" badge if AI-generated
- Location tag (if the author added one) and creation date on the same line

The component accepts a list of posts to display. If there's a problem loading posts, it shows an error message with a retry button. While posts are loading, a spinner appears.

The whole design is clean and focused on readability, with generous whitespace and a careful balance between the different elements. The spacing between title, summary, image, and body text is tuned so nothing feels cramped or too spread out.
