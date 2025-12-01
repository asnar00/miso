# reparent-post implementation (pseudocode)

## Database Function: set_post_parent

**Purpose**: Update the parent_id field of a post to establish parent-child relationships in the post tree.

**Parameters**:
- `post_id`: The ID of the post to be reparented
- `parent_id`: The ID of the new parent post (or null to make it a root post)

**Returns**: Success or failure status

**Logic**:
1. If parent_id is provided, verify the parent post exists in the database
2. Verify the child post exists in the database
3. Update the post's parent_id field to the new parent value
4. Commit the transaction

**Error Handling**:
- Return failure if parent post doesn't exist
- Return failure if child post doesn't exist
- Rollback transaction on any database error

## API Endpoint: /api/posts/reparent

**Purpose**: Allow setting parent-child relationships between posts via HTTP API.

**HTTP Method**: POST

**Request Body** (JSON):
```json
{
  "post_id": 123,
  "parent_id": 456
}
```

**Response** (JSON):
```json
{
  "status": "success"
}
```

**Logic**:
1. Extract post_id and parent_id from request body
2. Validate both IDs are provided
3. Call set_post_parent database function
4. Return success or error response

**Patching Instructions**:
- Database function should be added to the database module (db.py for Python)
- API endpoint should be added to the Flask app (app.py for Python)
