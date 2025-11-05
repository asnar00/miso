# templates Python implementation

## Migration Scripts

### create_templates.py

Complete migration script that sets up the templates system:

```python
"""
Create templates table and migrate placeholder data from posts table
"""

import psycopg2

def create_templates_table():
    """Create templates table and migrate existing placeholder data"""

    db_config = {
        'host': 'localhost',
        'port': '5432',
        'database': 'firefly',
        'user': 'microserver',
        'password': ''
    }

    conn = psycopg2.connect(**db_config)

    try:
        with conn.cursor() as cur:
            # Create templates table
            print("Creating templates table...")
            cur.execute("""
                CREATE TABLE IF NOT EXISTS templates (
                    name TEXT PRIMARY KEY,
                    placeholder_title TEXT NOT NULL,
                    placeholder_summary TEXT NOT NULL,
                    placeholder_body TEXT NOT NULL
                )
            """)

            # Insert default templates
            print("Inserting default templates...")
            cur.execute("""
                INSERT INTO templates (name, placeholder_title, placeholder_summary, placeholder_body)
                VALUES
                    ('post', 'Title', 'Summary', 'Body'),
                    ('profile', 'name', 'mission', 'personal statement')
                ON CONFLICT (name) DO NOTHING
            """)

            # Add template_name column to posts table
            print("Adding template_name column to posts table...")
            cur.execute("""
                ALTER TABLE posts
                ADD COLUMN IF NOT EXISTS template_name TEXT DEFAULT 'post'
            """)

            # Update the asnaroo post to use profile template
            print("Setting asnaroo post to use profile template...")
            cur.execute("""
                UPDATE posts
                SET template_name = 'profile'
                WHERE title = 'asnaroo'
            """)

            # Drop old placeholder columns from posts table (if migrating)
            print("Dropping old placeholder columns from posts table...")
            cur.execute("""
                ALTER TABLE posts
                DROP COLUMN IF EXISTS title_placeholder,
                DROP COLUMN IF EXISTS summary_placeholder,
                DROP COLUMN IF EXISTS body_placeholder
            """)

            conn.commit()
            print("Successfully created templates system!")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    create_templates_table()
```

**Run with:**
```bash
ssh microserver@185.96.221.52 "cd ~/firefly-server && python3 create_templates.py"
```

### grant_template_permissions.py

Grants SELECT permission on templates table to application user:

```python
"""
Grant permissions on templates table to firefly_user
"""

import psycopg2

def grant_permissions():
    """Grant SELECT permission on templates table"""

    db_config = {
        'host': 'localhost',
        'port': '5432',
        'database': 'firefly',
        'user': 'microserver',
        'password': ''
    }

    conn = psycopg2.connect(**db_config)

    try:
        with conn.cursor() as cur:
            print("Granting SELECT permission on templates table to firefly_user...")
            cur.execute("""
                GRANT SELECT ON templates TO firefly_user
            """)

            conn.commit()
            print("Successfully granted permissions!")

    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    grant_permissions()
```

**Run with:**
```bash
ssh microserver@185.96.221.52 "cd ~/firefly-server && python3 grant_template_permissions.py"
```

## Database Access

### Querying Posts with Templates

All SELECT queries in `db.py` include LEFT JOIN with templates:

```python
def get_recent_posts(limit=10):
    """Fetch recent posts with template placeholders"""
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
               p.created_at, p.timezone, p.location_tag, p.ai_generated,
               p.template_name,
               t.placeholder_title, t.placeholder_summary, t.placeholder_body,
               COALESCE(u.name, u.email) as author_name,
               u.email as author_email,
               COUNT(children.id) as child_count
        FROM posts p
        LEFT JOIN users u ON p.user_id = u.id
        LEFT JOIN templates t ON p.template_name = t.name
        LEFT JOIN posts children ON children.parent_id = p.id
        GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body
        ORDER BY p.created_at DESC
        LIMIT %s
        """,
        (limit,)
    )

    rows = cur.fetchall()
    cur.close()
    conn.close()

    return [dict(row) for row in rows]
```

### Building Post Dictionary

```python
def build_post_dict(row):
    """Convert database row to post dictionary"""
    return {
        'id': row[0],
        'user_id': row[1],
        'parent_id': row[2],
        'title': row[3],
        'summary': row[4],
        'body': row[5],
        'image_url': row[6],
        'created_at': row[7],
        'timezone': row[8],
        'location_tag': row[9],
        'ai_generated': row[10],
        'template_name': row[11],
        'placeholder_title': row[12],
        'placeholder_summary': row[13],
        'placeholder_body': row[14],
        'author_name': row[15],
        'author_email': row[16],
        'child_count': row[17]
    }
```

## Database Configuration

### Connection Setup

The system uses two database users:

**microserver** (table owner):
- Used for schema changes (CREATE, ALTER, DROP)
- Empty password on localhost
- Used by migration scripts

```python
db_config_admin = {
    'host': 'localhost',
    'port': '5432',
    'database': 'firefly',
    'user': 'microserver',
    'password': ''
}
```

**firefly_user** (application user):
- Used by Flask application
- Password: firefly123
- SELECT, INSERT, UPDATE, DELETE only

```python
db_config_app = {
    'host': 'localhost',
    'port': '5432',
    'database': 'firefly',
    'user': 'firefly_user',
    'password': 'firefly123'
}
```

### Permission Management

After creating templates table, grant permissions:

```sql
-- Application user needs SELECT on templates
GRANT SELECT ON templates TO firefly_user;

-- If templates become user-editable, add:
GRANT INSERT, UPDATE, DELETE ON templates TO firefly_user;
```

## Server Location

**Remote Server**: 185.96.221.52 (Mac mini on local network)
**Directory**: ~/firefly-server/
**Database**: PostgreSQL 5432 (localhost only, SSH required)

### PostgreSQL Client

psql is not in PATH on the remote server. Use full path:

```bash
/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U firefly_user -d firefly
```

### Query Database via SSH

```bash
# As application user
ssh microserver@185.96.221.52 "/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U firefly_user -d firefly -c 'SELECT * FROM templates;'"

# As admin (for schema changes)
ssh microserver@185.96.221.52 "/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U microserver -d firefly -c 'ALTER TABLE ...;'"
```

## Implementation Details

### Template Selection Query

Query to get all templates:

```python
def get_all_templates():
    """Fetch all available templates"""
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT name, placeholder_title, placeholder_summary, placeholder_body FROM templates ORDER BY name")
    rows = cur.fetchall()

    cur.close()
    conn.close()

    return [
        {
            'name': row[0],
            'placeholder_title': row[1],
            'placeholder_summary': row[2],
            'placeholder_body': row[3]
        }
        for row in rows
    ]
```

### Assigning Template to Post

```python
def assign_template(post_id, template_name):
    """Assign a template to a post"""
    # Validate template exists
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT name FROM templates WHERE name = %s", (template_name,))
    if not cur.fetchone():
        cur.close()
        conn.close()
        raise ValueError(f"Template not found: {template_name}")

    # Update post
    cur.execute("UPDATE posts SET template_name = %s WHERE id = %s", (template_name, post_id))
    conn.commit()

    cur.close()
    conn.close()
```

### Creating New Template

```python
def create_template(name, title_label, summary_label, body_label):
    """Create a new template (admin function)"""
    conn = get_db_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            INSERT INTO templates (name, placeholder_title, placeholder_summary, placeholder_body)
            VALUES (%s, %s, %s, %s)
            """,
            (name, title_label, summary_label, body_label)
        )
        conn.commit()
    except psycopg2.IntegrityError:
        conn.rollback()
        raise ValueError(f"Template already exists: {name}")
    finally:
        cur.close()
        conn.close()
```

## API Endpoints (Future)

Templates are currently managed via database scripts. Future API endpoints could include:

### GET /api/templates

List all available templates:

```python
@app.route('/api/templates', methods=['GET'])
def list_templates():
    templates = get_all_templates()
    return jsonify({'status': 'success', 'templates': templates})
```

**Response:**
```json
{
    "status": "success",
    "templates": [
        {
            "name": "post",
            "placeholder_title": "Title",
            "placeholder_summary": "Summary",
            "placeholder_body": "Body"
        },
        {
            "name": "profile",
            "placeholder_title": "name",
            "placeholder_summary": "mission",
            "placeholder_body": "personal statement"
        }
    ]
}
```

### POST /api/posts/{id}/template

Change a post's template:

```python
@app.route('/api/posts/<int:post_id>/template', methods=['POST'])
def update_post_template(post_id):
    data = request.get_json()
    template_name = data.get('template_name')

    # Verify user owns the post
    # ... authentication logic ...

    try:
        assign_template(post_id, template_name)
        return jsonify({'status': 'success'})
    except ValueError as e:
        return jsonify({'status': 'error', 'message': str(e)}), 400
```

## Testing

### Verify Templates Table

```bash
ssh microserver@185.96.221.52 "/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U firefly_user -d firefly -c 'SELECT * FROM templates;'"
```

Expected output:
```
  name   | placeholder_title | placeholder_summary |  placeholder_body
---------+-------------------+---------------------+--------------------
 post    | Title             | Summary             | Body
 profile | name              | mission             | personal statement
```

### Verify Posts Have Templates

```bash
ssh microserver@185.96.221.52 "/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U firefly_user -d firefly -c 'SELECT id, title, template_name FROM posts LIMIT 5;'"
```

### Test API Response

```bash
curl -s "http://185.96.221.52:8080/api/posts/recent?limit=1" | python3 -m json.tool
```

Look for placeholder fields in response:
```json
{
    "posts": [
        {
            "id": 22,
            "title": "asnaroo",
            "template_name": "profile",
            "placeholder_title": "name",
            "placeholder_summary": "mission",
            "placeholder_body": "personal statement",
            ...
        }
    ]
}
```

## Troubleshooting

### Permission Denied Error

**Error:** `permission denied for table templates`

**Cause:** firefly_user doesn't have SELECT permission on templates table

**Fix:**
```bash
ssh microserver@185.96.221.52 "cd ~/firefly-server && python3 grant_template_permissions.py"
```

### Empty Posts Response

**Error:** API returns `{"posts": [], "status": "success"}`

**Cause:** Usually permission error on templates table (fails silently in LEFT JOIN)

**Debug:**
```bash
ssh microserver@185.96.221.52 "cd ~/firefly-server && tail -50 server.log"
```

### Template Not Found

**Error:** Post shows default placeholders instead of custom ones

**Causes:**
1. Post's template_name references non-existent template
2. LEFT JOIN succeeded but template row is NULL
3. Client code falling back to defaults

**Debug:**
```sql
-- Check post's template_name
SELECT id, title, template_name FROM posts WHERE id = 22;

-- Check if template exists
SELECT * FROM templates WHERE name = 'profile';

-- Check JOIN result
SELECT p.id, p.template_name, t.placeholder_title
FROM posts p
LEFT JOIN templates t ON p.template_name = t.name
WHERE p.id = 22;
```

## Migration Checklist

When setting up templates system:

- [ ] Run create_templates.py as microserver user
- [ ] Verify templates table exists
- [ ] Verify default templates inserted
- [ ] Verify posts.template_name column exists
- [ ] Run grant_template_permissions.py
- [ ] Verify firefly_user can SELECT from templates
- [ ] Update all SELECT queries in db.py to include LEFT JOIN
- [ ] Add template fields to GROUP BY clauses
- [ ] Deploy updated server code
- [ ] Test API returns placeholder fields
- [ ] Update client models to include placeholder fields
- [ ] Deploy updated client apps
