# new post
*a quick interface to create a new post*

In the `view-posts` feature, we show the user a list of posts in compact form, and allow them to read them.

`new-post` adds a dummy compact item ("new post") before the first compact post, which is just a button. Pressing the button creates a new editable post (title, sub-title, image, and text); at the bottom is a "post" that sends the new post to the database.

To choose a picture, the user clicks on a small button and then selects either front or back camera app, or chooses a picture from the photo library. This picture then gets uploaded to the server along with the post itself.

Even though the underlying data structure is a single markdown file, the user interface should show each field (title, subtitle, picture, body) as a separate editable element.