# templates pseudocode

## Data Structures

```
Template {
    name: string (primary key)
    placeholderTitle: string
    placeholderSummary: string
    placeholderBody: string
}

Post {
    id: integer
    templateName: string (default: "post")
    ... other fields
}
```

## Database Schema

### Templates Table

```sql
CREATE TABLE templates (
    name TEXT PRIMARY KEY,
    placeholder_title TEXT NOT NULL,
    placeholder_summary TEXT NOT NULL,
    placeholder_body TEXT NOT NULL
);
```

### Default Data

```sql
INSERT INTO templates (name, placeholder_title, placeholder_summary, placeholder_body)
VALUES
    ('post', 'Title', 'Summary', 'Body'),
    ('profile', 'name', 'mission', 'personal statement')
ON CONFLICT (name) DO NOTHING;
```

### Posts Table Reference

```sql
ALTER TABLE posts
ADD COLUMN template_name TEXT DEFAULT 'post';
```

## Core Operations

### getTemplate(name)
```
function getTemplate(templateName):
    query = "SELECT * FROM templates WHERE name = ?"
    result = database.execute(query, templateName)
    return result
```

### getPostWithTemplate(postId)
```
function getPostWithTemplate(postId):
    query = """
        SELECT p.*,
               t.placeholder_title,
               t.placeholder_summary,
               t.placeholder_body
        FROM posts p
        LEFT JOIN templates t ON p.template_name = t.name
        WHERE p.id = ?
    """
    result = database.execute(query, postId)
    return result
```

### assignTemplate(postId, templateName)
```
function assignTemplate(postId, templateName):
    // Verify template exists
    template = getTemplate(templateName)
    if template is null:
        throw error("Template not found: " + templateName)

    // Update post
    query = "UPDATE posts SET template_name = ? WHERE id = ?"
    database.execute(query, templateName, postId)
```

### createTemplate(name, titleLabel, summaryLabel, bodyLabel)
```
function createTemplate(name, titleLabel, summaryLabel, bodyLabel):
    query = """
        INSERT INTO templates (name, placeholder_title, placeholder_summary, placeholder_body)
        VALUES (?, ?, ?, ?)
    """
    database.execute(query, name, titleLabel, summaryLabel, bodyLabel)
```

## Integration with Posts

When fetching posts, always include template placeholders via JOIN:

```sql
SELECT p.id, p.title, p.summary, p.body, p.template_name,
       t.placeholder_title, t.placeholder_summary, t.placeholder_body,
       ... other fields
FROM posts p
LEFT JOIN templates t ON p.template_name = t.name
WHERE ...
```

**Why LEFT JOIN?**
- Posts with invalid template_name still return (with NULL placeholders)
- System can fall back to defaults in application code
- More resilient to data inconsistencies

## Client-Side Usage

### Displaying Placeholders

```
function getPlaceholder(post, fieldName):
    switch fieldName:
        case "title":
            return post.placeholderTitle ?? "Title"
        case "summary":
            return post.placeholderSummary ?? "Summary"
        case "body":
            return post.placeholderBody ?? "Body"
```

### Edit View

```
TextField(
    text: post.title,
    placeholder: post.placeholderTitle ?? "Title"
)

TextField(
    text: post.summary,
    placeholder: post.placeholderSummary ?? "Summary"
)

TextEditor(
    text: post.body,
    placeholder: post.placeholderBody ?? "Body"
)
```

## Validation

### Template Name Validation

```
function isValidTemplateName(name):
    // Only lowercase letters and hyphens
    pattern = "^[a-z][a-z0-9-]*$"
    return name matches pattern
```

### Placeholder Validation

```
function isValidPlaceholder(text):
    // Placeholders should be short and descriptive
    if text.length < 1 or text.length > 50:
        return false

    // No newlines or special characters
    if text contains newline:
        return false

    return true
```

## Migration Pattern

When creating templates system:

1. Create templates table
2. Insert default templates
3. Add template_name column to posts with default value
4. Update specific posts to use custom templates
5. Grant SELECT permissions to application user
6. Update all SELECT queries to include LEFT JOIN

## Patching Instructions

### Server (Python/Flask)

**Update all post queries to include template JOIN:**

```python
# Before
cur.execute("SELECT * FROM posts WHERE id = %s", (post_id,))

# After
cur.execute("""
    SELECT p.*,
           t.placeholder_title,
           t.placeholder_summary,
           t.placeholder_body
    FROM posts p
    LEFT JOIN templates t ON p.template_name = t.name
    WHERE p.id = %s
""", (post_id,))
```

**Important**: Include template placeholders in GROUP BY when using aggregates:

```python
GROUP BY p.id, p.title, ..., t.placeholder_title, t.placeholder_summary, t.placeholder_body
```

### Client (iOS/Swift)

**Add placeholder fields to Post model:**

```swift
struct Post: Codable {
    let id: Int
    let title: String
    let templateName: String?
    let titlePlaceholder: String?
    let summaryPlaceholder: String?
    let bodyPlaceholder: String?

    enum CodingKeys: String, CodingKey {
        case templateName = "template_name"
        case titlePlaceholder = "placeholder_title"
        case summaryPlaceholder = "placeholder_summary"
        case bodyPlaceholder = "placeholder_body"
        // ... other cases
    }
}
```

**Use placeholders in views:**

```swift
TextField("", text: $title,
          prompt: Text(post.titlePlaceholder ?? "Title"))
```

## Design Rationale

### Why Not Store Placeholders on Posts?

**Denormalized approach (NOT used):**
```sql
-- Don't do this
ALTER TABLE posts
ADD COLUMN title_placeholder TEXT,
ADD COLUMN summary_placeholder TEXT,
ADD COLUMN body_placeholder TEXT;
```

**Problems:**
- Duplicates data across thousands of posts
- Hard to change placeholder text globally
- Wastes storage space
- Requires schema changes to add new templates

**Templates approach (used):**
- One row per template, referenced by name
- Change placeholder text in one place
- No schema changes for new templates
- Clear separation of concerns

### Why String Key Instead of Integer ID?

Template names are:
- **Human-readable**: "profile" is clearer than "2"
- **Stable**: Won't change between environments
- **Self-documenting**: Code is easier to understand
- **Safe**: Can't accidentally use wrong ID

### Why Default to "post"?

- Most posts are regular blog-style posts
- New posts work immediately without choosing template
- Explicit about the standard case
- Easy to change for special cases

## Security Considerations

### Template Injection

**Problem**: User-supplied template names could cause SQL injection

**Solution**: Always validate template names before queries:

```python
VALID_TEMPLATE_NAME = re.compile(r'^[a-z][a-z0-9-]*$')

def validate_template_name(name):
    if not VALID_TEMPLATE_NAME.match(name):
        raise ValueError("Invalid template name")
    return name
```

### Permission Boundaries

- Application user (firefly_user): SELECT only
- Admin user (microserver): CREATE/ALTER/DROP
- Never allow client to create templates directly
- Template management is admin function

## Performance Considerations

### Query Performance

LEFT JOIN with templates adds minimal overhead:
- Templates table is tiny (< 100 rows expected)
- Primary key lookup is O(1)
- JOIN happens on indexed column
- Negligible impact on query time

### Caching Strategy

Templates rarely change, so they're perfect for caching:

```python
# Simple in-memory cache
_template_cache = {}

def get_template(name):
    if name not in _template_cache:
        _template_cache[name] = fetch_from_database(name)
    return _template_cache[name]
```

## Future Extensions

### Template Metadata

Could extend templates table with:

```sql
ALTER TABLE templates
ADD COLUMN description TEXT,
ADD COLUMN icon_name TEXT,
ADD COLUMN created_at TIMESTAMP,
ADD COLUMN is_system BOOLEAN;
```

### Field Configuration

Could make fields configurable per template:

```sql
CREATE TABLE template_fields (
    template_name TEXT REFERENCES templates(name),
    field_name TEXT,
    label TEXT,
    required BOOLEAN,
    min_length INTEGER,
    max_length INTEGER,
    PRIMARY KEY (template_name, field_name)
);
```

### Template Inheritance

Could allow templates to extend other templates:

```sql
ALTER TABLE templates
ADD COLUMN extends TEXT REFERENCES templates(name);
```
