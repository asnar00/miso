# Firefly Server

## Database Access

### Database Configuration

**Remote Server**: 185.96.221.52:5432
**Database**: firefly

**Users**:
- `microserver` (empty password): Table owner, can ALTER/CREATE/DROP tables
- `firefly_user` (password: firefly123): Application user, SELECT/INSERT/UPDATE/DELETE only

### Querying the Database

The PostgreSQL server only listens on localhost, so you must SSH to the server first.

**psql is not in PATH** - you must use the full path:
```bash
/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql
```

#### Using psql via SSH

```bash
# Query as application user
ssh microserver@185.96.221.52 "/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U firefly_user -d firefly -c 'SELECT * FROM posts LIMIT 5;'"

# Query as database owner (for schema changes)
ssh microserver@185.96.221.52 "/opt/homebrew/Cellar/postgresql@16/16.10/bin/psql -U microserver -d firefly -c 'ALTER TABLE ...;'"
```

#### Using Python via SSH

```bash
ssh microserver@185.96.221.52 "cd ~/firefly-server && python3 -c \"
import psycopg2
conn = psycopg2.connect(host='localhost', port='5432', database='firefly', user='firefly_user', password='firefly123')
cur = conn.cursor()
cur.execute('SELECT * FROM posts LIMIT 5')
print(cur.fetchall())
cur.close()
conn.close()
\""
```

### Schema Migrations

Run migration scripts as `microserver` user:

```bash
# On remote server
ssh microserver@185.96.221.52
cd ~/firefly-server
python3 create_tables.py  # or any migration script
```

Migration scripts should use:
```python
db_config = {
    'host': 'localhost',
    'port': '5432',
    'database': 'firefly',
    'user': 'microserver',
    'password': ''
}
```

After creating new tables, grant permissions:
```sql
GRANT SELECT ON new_table TO firefly_user;
GRANT INSERT, UPDATE, DELETE ON new_table TO firefly_user;  -- if needed
```

### Current Schema

**posts table**:
- Standard post fields: id, user_id, parent_id, title, summary, body, image_url, etc.
- `template_name TEXT DEFAULT 'post'`: References templates table

**templates table**:
- `name TEXT PRIMARY KEY`: Template identifier (e.g., 'post', 'profile')
- `placeholder_title TEXT`: Placeholder for title field
- `placeholder_summary TEXT`: Placeholder for summary field
- `placeholder_body TEXT`: Placeholder for body field

**users table**: User accounts and authentication

**images table**: Image metadata and storage
