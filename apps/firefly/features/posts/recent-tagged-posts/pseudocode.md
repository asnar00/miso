# Recent Tagged Posts - Pseudocode

## Data Structures

```
Template {
    name: string (e.g., "post", "profile", "query")
    placeholder_title: string
    placeholder_summary: string
    placeholder_body: string
    plural_name: string (e.g., "posts", "profiles", "queries")
}

Post {
    id: integer
    user_id: integer
    parent_id: integer? (-1 for root posts)
    title: string
    summary: string
    body: string
    image_url: string?
    created_at: timestamp
    timezone: string
    location_tag: string?
    ai_generated: boolean
    template_name: string
    author_name: string
    author_email: string
    child_count: integer
    placeholder_title: string (from template)
    placeholder_summary: string (from template)
    placeholder_body: string (from template)
    plural_name: string? (from template)
}
```

## Server API

### Endpoint: GET /api/posts/recent-tagged

**Parameters:**
- `tags`: comma-separated template names (e.g., "query,post")
- `by_user`: "any" or "current"
- `user_email`: email of current user (required if by_user="current")
- `limit`: number of posts to return (default: 50)

**Query Logic:**
```sql
SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
       p.created_at, p.timezone, p.location_tag, p.ai_generated, p.template_name,
       t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name,
       COALESCE(u.name, u.email) as author_name,
       u.email as author_email,
       COUNT(children.id) as child_count
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN templates t ON p.template_name = t.name
LEFT JOIN posts children ON children.parent_id = p.id
WHERE p.template_name IN (tags)              -- if tags provided
  AND p.user_id = :user_id                   -- if by_user="current"
GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name
ORDER BY
  CASE WHEN 'profile' IN tags THEN
    (SELECT MAX(created_at) FROM posts WHERE user_id = p.user_id)
  ELSE
    p.created_at
  END DESC
LIMIT :limit
```

**CRITICAL:** The GROUP BY must include `t.plural_name` to avoid SQL errors when the column is selected.

**Response:**
```json
{
  "status": "success",
  "posts": [Post, Post, ...]
}
```

### Endpoint: GET /api/templates/:template_name

Returns template information including plural_name.

**CRITICAL - Connection Pool Management:**

This endpoint MUST properly return database connections to the pool using a `finally` block. Failure to do this causes connection pool exhaustion and server crashes.

**Correct implementation pattern:**
```python
conn = db.get_connection()
try:
    # Use connection
    with conn.cursor() as cur:
        cur.execute("SELECT ...")
        result = cur.fetchone()
    return jsonify(result)
except Exception as e:
    return jsonify({'error': str(e)}), 500
finally:
    db.return_connection(conn)  # CRITICAL: Always return connection
```

**Response:**
```json
{
  "status": "success",
  "template": {
    "name": "query",
    "placeholder_title": "query title",
    "placeholder_summary": "query",
    "placeholder_body": "query details",
    "plural_name": "queries"
  }
}
```

### Endpoint: POST /api/posts/create

**CRITICAL:** Must read `template_name` from request form data, not hardcode it.

**Form Parameters:**
- `email`: user's email (required)
- `title`, `summary`, `body`: post content (required)
- `timezone`: user's timezone (default: "UTC")
- `parent_id`: parent post ID (optional, defaults to user's profile)
- `template_name`: template type (optional, defaults to "post")
- `image`: image file (optional)

**Server Logic:**
```python
template_name = request.form.get('template_name', 'post').strip()

post_id = db.create_post(
    user_id=user_id,
    title=title,
    summary=summary,
    body=body,
    timezone=timezone,
    parent_id=parent_id,
    image_url=image_url,
    template_name=template_name  # Use the provided template_name
)
```

## Client Implementation

### Fetching Posts

```
function fetchRecentTaggedPosts(tags, byUser):
    url = "/api/posts/recent-tagged"
    params = {
        tags: tags.join(","),
        by_user: byUser
    }

    if byUser == "current":
        params.user_email = getCurrentUserEmail()

    response = HTTP.GET(url, params)
    return response.posts
```

### Display with Empty State

```
PostsListView {
    templateName: string?  // e.g., "query"
    initialPosts: Post[]

    state {
        posts: Post[] = initialPosts
        pluralName: string? = null
    }

    onAppear():
        if templateName:
            fetchPluralName(templateName)

    fetchPluralName(templateName):
        template = HTTP.GET("/api/templates/" + templateName)
        pluralName = template.plural_name

    emptyStateMessage():
        if pluralName:
            return "No " + pluralName + " yet"
        if initialPosts[0]?.pluralName:
            return "No " + initialPosts[0].pluralName + " yet"
        return "No posts yet"

    render():
        if posts.isEmpty:
            show emptyStateMessage()
        else:
            show posts
}
```

### Smart Add Button

```
shouldShowAddButton():
    // Don't show for child posts (only root level)
    if parentPostId != null:
        return false

    // Don't show for profiles
    if posts[0]?.template == "profile":
        return false

    return true

addButtonTemplate():
    if posts[0]?.template:
        return posts[0].template
    return parentPostId == null ? "query" : "post"

addButtonText():
    template = addButtonTemplate()
    return "Add " + capitalize(template)
```

### Creating New Posts

When creating a new post with a specific template:

```
createNewPost():
    templateName = addButtonTemplate()

    newPost = Post {
        id: -1,  // Temporary ID
        template: templateName,
        title: "",
        summary: "",
        body: "",
        // ... other fields
    }

    posts.insert(newPost, at: 0)
    expand(newPost)
    editingPostId = newPost.id
```

When saving the post to server, **MUST include template_name** in the request:

```
savePost(post):
    if post.id < 0:  // New post
        fields = {
            email: userEmail,
            title: post.title,
            summary: post.summary,
            body: post.body,
            template_name: post.template  // CRITICAL: Include template_name for new posts
        }
        response = HTTP.POST("/api/posts/create", fields)
```

## Patching Instructions

### For iOS PostView

**File:** `NoobTest/PostView.swift`

**Location:** In the `saveChanges()` function, when building form fields for new posts.

**CRITICAL:** This needs to be added in BOTH places where form fields are built (with image upload and without):

**With image (multipart form):**
```swift
// For updates, include post_id; for new posts, optionally include parent_id and template_name
if !isNewPost {
    fields["post_id"] = String(post.id)
}
if let parentId = post.parentId {
    fields["parent_id"] = String(parentId)
}
if isNewPost, let templateName = post.template {
    fields["template_name"] = templateName  // ADD THIS
}
```

**Without image (URL-encoded form):**
```swift
// For updates, include post_id; for new posts, optionally include parent_id and template_name
if !isNewPost {
    formData["post_id"] = String(post.id)
    formData["image_url"] = editableImageUrl ?? ""
}
if let parentId = post.parentId {
    formData["parent_id"] = String(parentId)
}
if isNewPost, let templateName = post.template {
    formData["template_name"] = templateName  // ADD THIS
}
```

### For Server Database Query

**File:** `db.py`

**Function:** `get_recent_tagged_posts()`

**CRITICAL FIX:**
```python
# Group by - MUST include t.plural_name
query += " GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body, t.plural_name"
```

Forgetting `t.plural_name` in GROUP BY causes a SQL error that returns empty results silently.

### For Server Post Creation

**File:** `app.py`

**Function:** `create_post()`

**CRITICAL FIX - Read template_name from request:**
```python
# Get optional template_name (defaults to 'post')
template_name = request.form.get('template_name', 'post').strip()

# Later when creating the post:
post_id = db.create_post(
    user_id=user_id,
    title=title,
    summary=summary,
    body=body,
    timezone=timezone,
    parent_id=parent_id,
    image_url=image_url,
    location_tag=location_tag,
    ai_generated=ai_generated,
    template_name=template_name  # Use the value from request, not hardcoded
)
```

**DO NOT hardcode:** `template_name='post'` - this was the bug that caused all new queries to be tagged as "post".

### For Server Connection Pool Management

**File:** `app.py`

**Function:** `get_template()`

**CRITICAL FIX - Add finally block to return connection:**

The original implementation acquired a database connection but never returned it, causing connection pool exhaustion after repeated requests. The server would crash with "connection pool exhausted" errors.

**Broken code (DO NOT USE):**
```python
@app.route('/api/templates/<template_name>', methods=['GET'])
def get_template(template_name):
    try:
        conn = db.get_connection()  # Connection acquired
        # ... use connection ...
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    # Connection NEVER returned - LEAK!
```

**Fixed code:**
```python
@app.route('/api/templates/<template_name>', methods=['GET'])
def get_template(template_name):
    conn = db.get_connection()  # Acquire connection outside try block
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT name, placeholder_title, placeholder_summary, placeholder_body, plural_name
                FROM templates
                WHERE name = %s
            """, (template_name,))
            row = cur.fetchone()
            if not row:
                return jsonify({'status': 'error', 'message': 'Template not found'}), 404

            template = {
                'name': row[0],
                'placeholder_title': row[1],
                'placeholder_summary': row[2],
                'placeholder_body': row[3],
                'plural_name': row[4]
            }
            return jsonify({'status': 'success', 'template': template})
    except Exception as e:
        return jsonify({'status': 'error', 'message': f'Server error: {str(e)}'}), 500
    finally:
        db.return_connection(conn)  # ALWAYS return connection
```

**Symptoms of connection pool leak:**
- Server crashes after multiple requests
- Error logs show: `psycopg2.pool.PoolError: connection pool exhausted`
- All subsequent requests return 500 errors
- Server becomes unresponsive

**How to diagnose:**
```bash
# Check server logs for connection pool errors
ssh microserver@185.96.221.52 "cd ~/firefly-server && tail -100 server.log | grep -i pool"

# Look for "connection pool exhausted" errors
```

**Prevention rule:**
Every function that calls `db.get_connection()` MUST have this pattern:
```python
conn = db.get_connection()  # Acquire outside try
try:
    # Use connection
    pass
finally:
    db.return_connection(conn)  # ALWAYS return in finally
```

## Database Schema

**templates table:**
```sql
CREATE TABLE templates (
    name VARCHAR(50) PRIMARY KEY,
    placeholder_title VARCHAR(100),
    placeholder_summary VARCHAR(200),
    placeholder_body VARCHAR(500),
    plural_name VARCHAR(50)  -- Added for empty state messages
);
```

**Sample data:**
```sql
INSERT INTO templates VALUES
  ('post', 'Title', 'Summary', 'Body', 'posts'),
  ('profile', 'name', 'mission', 'personal statement', 'profiles'),
  ('query', 'query title', 'query', 'query details', 'queries');
```
