# edit-posts
*users can edit their own posts after creating them*

When viewing an expanded post, users who own the post see a pencil icon button in the author information bar at the bottom of the post.

**Entering Edit Mode:**
When the user taps the pencil button:
- The title, summary, and body text all become editable with text fields
- Light grey backgrounds appear around each editable section
- The pencil button is replaced with two buttons: a red undo arrow (cancel) and a green checkmark (save)
- Text can be edited freely in all three fields
- As the user types in the body, the post height adjusts automatically to fit the content
- If the post has an image, it displays with a red trash button to delete the image
- Users can add a new image using an "Add Image" button (camera or photo library)

**Visual Indicators:**
- Grey background (10% opacity) highlights editable sections
- Title: single-line bold text field
- Summary: italic text field, up to 2 lines when not editing
- Body: multi-line text editor with dynamic height
- Edit buttons appear in the author bar next to the author's name
- Image edit buttons (when image exists): three buttons overlaid on top-right corner
  - Red trash icon (trash.circle.fill) - delete image
  - Blue photo icon (photo.circle.fill) - replace from photo library
  - Green camera icon (camera.circle.fill) - take new photo with camera
- Add Image button (when no image): black text with black outline, "photo.badge.plus" icon
- Cancel button: red undo arrow icon (arrow.uturn.backward.circle.fill)

**Editing Experience:**
- No spell-check red underlines appear while editing
- No automatic capitalization at the start of sentences
- The body text editor expands vertically as needed
- Layout maintains proper spacing between all elements
- Tapping on the post background or image does not collapse the post during editing
- The post remains expanded until save or cancel is pressed

**Image Editing:**
When in edit mode with an existing image:
- Three buttons appear overlaid in the top-right corner of the image
- Delete button (red trash icon): removes the image (pending save)
- Photo library button (blue photo icon): opens photo library to replace image
- Camera button (green camera icon): opens camera to take new photo

When in edit mode with no image:
- "Add Image" button appears with dialog options for camera or photo library

All image replacements and additions:
- Selected images are processed automatically:
  - EXIF orientation metadata is removed and pixels are reoriented
  - Image is resized to maximum 1200 pixels on longest edge (preserving aspect ratio)
  - Image is encoded as high-quality JPEG (90% quality)
  - Processed image displays immediately in the post
- Layout adjusts automatically to match new image aspect ratio
- Cancel restores original image and aspect ratio

**Saving Changes:**
When the user taps the green checkmark:
- All edited content (title, summary, body, image) is saved to the server
- New images are uploaded as multipart form data along with the post update
- Edit mode exits, showing the pencil button again
- All fields become read-only
- The changes persist across sessions and refreshes

**Canceling Edits:**
When the user taps the red undo arrow:
- All edits in all fields are discarded
- Original text and image are restored
- Original image aspect ratio is restored
- Edit mode exits, showing the pencil button again

**Location:**
Edit controls appear in the author information bar at the bottom of expanded posts, integrated with the author's name display.
