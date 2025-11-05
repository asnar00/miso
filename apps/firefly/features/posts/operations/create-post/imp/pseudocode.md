# create-post implementation (pseudocode)

## Database Function: create_post

**Purpose**: Create a new post in the database with all required metadata.

**Parameters**:
- `user_id`: ID of the user creating the post
- `title`: Post title
- `summary`: One-line summary (emphasized)
- `body`: Post body text (up to ~300 words)
- `timezone`: User's timezone (e.g., "Europe/Madrid")
- `parent_id`: Optional ID of parent post (for tree structure)
- `image_url`: Optional URL to uploaded image
- `location_tag`: Optional location string
- `ai_generated`: Boolean flag indicating if post was AI-generated
- `embedding`: Optional vector embedding for semantic search (768 dimensions)

**Returns**: Post ID if successful, None otherwise

**Logic**:
1. Insert new post record into database with all provided fields
2. Auto-generate created_at timestamp (UTC)
3. Return the new post's ID

## API Endpoint: /api/posts/create

**Purpose**: Create a new post via HTTP, handling multipart form data for text and image upload.

**HTTP Method**: POST

**Request Format**: multipart/form-data

**Form Fields**:
- `email` (required): Author's email address
- `title` (required): Post title
- `summary` (required): One-line summary
- `body` (required): Post body text
- `timezone` (optional, default: "UTC"): User's timezone
- `parent_id` (optional): ID of parent post (for creating child posts)
- `location_tag` (optional): Location string
- `ai_generated` (optional, default: false): Whether AI-generated
- `image` (optional): Image file upload (png, jpg, jpeg, gif, webp)

**Response** (JSON):
```json
{
  "status": "success",
  "post": {
    "id": 123,
    "title": "...",
    "summary": "...",
    ...
  }
}
```

**Logic**:
1. Extract form data from request
2. Validate required fields (email, title, summary, body)
3. If parent_id provided, validate it's a valid integer
4. Look up user by email address
5. **If parent_id NOT provided, get user's profile post and set parent_id to profile post's ID**
6. If image file present:
   - Validate file extension
   - Generate unique filename (UUID + extension)
   - Save to uploads folder
   - Store image URL as "/uploads/{filename}"
7. Call database create_post function with parent_id (either provided, or defaulted to profile post)
8. Retrieve and return the created post

**Error Handling**:
- 400: Missing required fields
- 404: User not found
- 500: Failed to create post or retrieve created post

**Patching Instructions**:
- Database function already exists in db.py
- API endpoint already exists in app.py
- Image uploads stored in uploads/ folder with 16MB max file size
