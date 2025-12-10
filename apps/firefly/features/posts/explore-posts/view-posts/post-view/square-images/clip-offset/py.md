# clip offset Python/Flask implementation
*server-side storage and API for clip offset*

## Files to modify

1. `server.py` - Add fields to database and API

## Database schema change

Add columns to posts table:
```sql
ALTER TABLE posts ADD COLUMN clip_offset_x REAL DEFAULT 0;
ALTER TABLE posts ADD COLUMN clip_offset_y REAL DEFAULT 0;
```

Or in table creation:
```sql
CREATE TABLE posts (
    -- ... existing columns ...
    clip_offset_x REAL DEFAULT 0,
    clip_offset_y REAL DEFAULT 0
);
```

## API changes

### GET /api/posts/{id} and list endpoints

Include in response:
```python
{
    # ... existing fields ...
    "clip_offset_x": row["clip_offset_x"] or 0,
    "clip_offset_y": row["clip_offset_y"] or 0
}
```

### POST /api/posts (create)

Accept optional fields:
```python
clip_offset_x = data.get("clip_offset_x", 0)
clip_offset_y = data.get("clip_offset_y", 0)
```

Include in INSERT:
```sql
INSERT INTO posts (..., clip_offset_x, clip_offset_y)
VALUES (..., ?, ?)
```

### PUT /api/posts/{id} (update)

Accept and update fields:
```python
clip_offset_x = data.get("clip_offset_x", 0)
clip_offset_y = data.get("clip_offset_y", 0)

UPDATE posts SET ..., clip_offset_x = ?, clip_offset_y = ? WHERE id = ?
```

## Validation

- Values should be between -1.0 and 1.0
- Default to 0 if not provided
- Clamp values if out of range:
```python
clip_offset_x = max(-1.0, min(1.0, float(data.get("clip_offset_x", 0))))
clip_offset_y = max(-1.0, min(1.0, float(data.get("clip_offset_y", 0))))
```

## Backwards compatibility

- Existing posts without these fields return 0 (centered)
- Old clients that don't send these fields work fine (defaults used)
- New clients on old server: fields ignored on save, return as 0
