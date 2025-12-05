# edit-posts
*users can create and edit posts with inline editing*

Users can create new posts inline at the top of the post list, and edit their own posts after creating them using the same unified editing interface.

**Creating New Posts:**
When the user taps the "Add Post" button at the top of the list:
- A new blank post appears at the top, immediately expanded in edit mode
- The post shows the user's actual name (fetched from their profile)
- Template placeholders appear: "Title", "Summary", "Body"
- The red undo button deletes the unsaved post
- The green checkmark saves it to the server
- After saving, the post stays expanded with its new server-assigned ID
- No page refresh occurs - the list doesn't collapse or jump

**Editing Existing Posts:**
When viewing an expanded post, users who own the post see a circular pencil button in the top-right corner. The button uses the standard button color (RGB 255/178/127 modified by brightness) with a drop shadow (40% black opacity, 8pt blur, 4pt downward offset) for visual consistency with other UI buttons.

**Entering Edit Mode:**
When the user taps the pencil button:
- The title, summary, and body text all become editable with text fields
- Light grey backgrounds appear around each editable section
- The pencil button disappears and three action buttons appear in the bottom-right corner:
  - Delete button (red trash, only for saved posts)
  - Undo button (red arrow, cancels changes)
  - Save button (green checkmark, saves changes)
- The child indicator button (+ button in right edge) is hidden during editing
- The bottom toolbar fades out and becomes non-interactive while editing
- Text can be edited freely in all three fields
- As the user types in the body, the post height adjusts automatically to fit the content
- If the post has an image, it displays with a red trash button to delete the image
- Users can add a new image using an "Add Image" button (camera or photo library)

**Visual Indicators:**
- Grey background (20% opacity) highlights editable sections
- Title: single-line bold text field
- Summary: italic text field, up to 2 lines when not editing
- Body: multi-line text editor with dynamic height
- Placeholder text (55% grey opacity) appears in empty fields with labels like "Title", "Summary", "Body"
- Some posts have custom placeholder text (e.g., "name", "mission", "personal statement")
- Edit button (not editing): Circular button (36x36pt) with pencil icon (18pt bold, black) in top-right corner, using standard button color with drop shadow
- Edit action buttons (while editing): Horizontal row in bottom-right corner
  - Delete button (saved posts only): red trash icon (32pt, red at 60% opacity)
  - Undo button: red arrow icon (32pt, red at 60% opacity)
  - Save button: green checkmark icon (32pt, green at 60% opacity)
- Image edit buttons (when image exists): three buttons overlaid on top-right corner of image
  - Red trash icon (trash.circle.fill) - delete image
  - Blue photo icon (photo.circle.fill) - replace from photo library
  - Green camera icon (camera.circle.fill) - take new photo with camera
- Add Image button (when no image): lowercase "add image" text with black outline, "photo.badge.plus" icon, positioned at Y=72pt
- Navigate to children button: stays at right edge, vertically centered, visible when not editing
- Bottom toolbar: fades out (0.3s animation) and becomes non-interactive during edit mode

**Editing Experience:**
- Autocorrect is enabled - misspelled words are automatically corrected as you type
- Autocapitalization is enabled for sentences - first letter of each sentence is capitalized
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
- "add image" button appears positioned at Y=72pt (snug below title/summary area)
- Button shows dialog with lowercase options: "take photo", "choose from library", "cancel"

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
- For new unsaved posts: the post is deleted from the list
- For existing posts: all edits in all fields are discarded
- Original text and image are restored (existing posts only)
- Original image aspect ratio is restored (existing posts only)
- Edit mode exits, showing the pencil button again (existing posts only)

**Deleting Posts:**
When the user taps the red trash button (bottom-right corner, visible only for saved posts in edit mode):
- A confirmation dialog appears: "Delete Post" with message "Are you sure you want to permanently delete this post?"
- Dialog has two buttons: "Cancel" (safe) and "Delete" (red, destructive)
- If user confirms deletion:
  - The post is permanently deleted from the server
  - The post disappears from all views in the app simultaneously (main list, search results, child views, etc.)
  - The deletion is irreversible
- This button only appears for saved posts (not new unsaved posts)

**Button Layout:**
- Edit button (not editing): top-right corner at (edit-button-x - 32, 16pt) where edit-button-x defaults to 334pt
- Edit action buttons (while editing): horizontal row in bottom-right at (edit-button-x - 120, currentHeight - 48)
  - Buttons spaced 8pt apart (tunable: edit-button-spacing)
  - Order: delete (if saved post), undo, save
- Navigate to children button: right edge with -6pt padding + 32pt offset, vertically centered
- All button positions use tunable constants for fine-tuning
