# find-children implementation (pseudocode)

## Database Function: get_child_posts

**Purpose**: Retrieve all child posts of a given parent post (posts where parent_id equals the specified post ID).

**Parameters**:
- `parent_id`: The ID of the parent post

**Returns**: List of child post dictionaries, ordered by creation time (oldest first)

**Logic**:
1. Query database for all posts where `parent_id = parent_id`
2. Order results by `created_at ASC` (oldest children first)
3. Return list of posts with all fields (id, user_id, parent_id, title, summary, body, image_url, created_at, timezone, location_tag, ai_generated)

**Note**: Uses indexed query on `parent_id` for fast lookup even with millions of posts.

## API Endpoint: /api/posts/<post_id>/children

**Purpose**: Get all children of a specific post via HTTP.

**HTTP Method**: GET

**URL Parameters**:
- `post_id`: The ID of the parent post (integer in URL path)

**Response** (JSON):
```json
{
  "status": "success",
  "post_id": 6,
  "count": 2,
  "children": [
    {
      "id": 7,
      "user_id": 7,
      "parent_id": 6,
      "title": "classic cherry pie",
      "summary": "a timeless dessert...",
      ...
    },
    {
      "id": 8,
      "user_id": 7,
      "parent_id": 6,
      "title": "beer",
      "summary": "the drink that dare not...",
      ...
    }
  ]
}
```

**Logic**:
1. Extract post_id from URL path
2. Call database get_child_posts function
3. Return list of children with count

**Error Handling**:
- 500: Server error during query
- Returns empty list if post has no children (not an error)

**Patching Instructions**:
- Database function already exists in db.py:247
- API endpoint should be added to app.py after the reparent endpoint
