# new-post implementation

*high-level implementation approach for creating new posts*

## Components

### NewPostButton
A compact button view that appears at the top of the posts list, before the first post.

**Visual design:**
- White rounded rectangle card (matches post card style)
- Left side: large "+" circle icon in turquoise (app accent color)
- Right side: "Create a new post" text in semibold, slightly faded black
- Tappable across the entire button area

**Behavior:**
- When tapped, opens the NewPostEditor modal

### NewPostEditor
A full-screen modal sheet for composing a new post.

**Layout:**
- Navigation bar with "Cancel" (left) and "Post" (right) buttons
- Title: "New Post"
- Background: turquoise (app background color)
- Main content: scrollable white card containing all editing fields

**Editing fields (in order):**
1. **Title field** - single-line text input, bold 24pt font, placeholder: "Title"
2. **Summary field** - single-line text input, italic subheadline font, placeholder: "Summary"
3. **Image selector/display**:
   - If no image: button showing "Image" with photo icon
   - If image selected: display image with X button in top-right corner to remove
4. **Body field** - multi-line text editor, body font, min height 200pt, placeholder: "Body"

**Image selection:**
- Tapping the image button shows a confirmation dialog with three options:
  - "Camera" - opens camera to take a new photo
  - "Photo Library" - opens photo picker to select existing photo
  - "Cancel"
- Uses platform image picker component

**Posting behavior:**
- "Post" button is disabled and grayed out when title is empty
- When "Post" is tapped:
  1. Show progress spinner in place of "Post" button
  2. Call PostsAPI.createPost with title, summary, body, image, and optional parentId
  3. On success: call onPostCreated callback (to refresh posts list), then dismiss modal
  4. On error: show error message below the editing card, allow retry

**Error handling:**
- Display error message in red text below the edit card
- Keep modal open so user can retry or edit

## Integration

**In PostsView:**
- Add NewPostButton at the top of the posts list (before first post)
- Wire button to show NewPostEditor as a sheet/modal
- Pass onPostCreated callback that refreshes the posts list

**PostsAPI.createPost:**
- Parameters: title (required), summary, body, image (optional UIImage/Bitmap), parentId (optional)
- Encode image as base64 or multipart form data
- POST to server endpoint /api/posts/create
- Handle success/error response
- Call completion handler with Result type

## Data validation

- Title is required (minimum field for posting)
- Summary defaults to "No summary" if empty
- Body defaults to "No content" if empty
- Image is optional
- ParentId is optional (null for top-level posts)
