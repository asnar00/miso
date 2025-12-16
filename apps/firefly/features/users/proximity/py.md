# proximity Python implementation
*PostgreSQL storage and server-side proximity calculation*

## Database migration

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS ancestor_chain INTEGER[];
```

## Migration function (db.py)

```python
def migrate_add_ancestor_chains(self):
    """Add ancestor_chain column to users table and populate for existing users"""
    conn = self.get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Add column if not exists
            cur.execute("""
                ALTER TABLE users
                ADD COLUMN IF NOT EXISTS ancestor_chain INTEGER[]
            """)
            conn.commit()

            # Get all users ordered by creation (oldest first ensures parents processed first)
            cur.execute("""
                SELECT id, invited_by, ancestor_chain
                FROM users
                ORDER BY created_at ASC NULLS FIRST, id ASC
            """)
            users = cur.fetchall()

            updated = 0
            for user in users:
                if user['ancestor_chain'] is not None:
                    continue  # Already has chain

                if user['invited_by'] is None:
                    chain = [user['id']]  # Root user
                else:
                    cur.execute(
                        "SELECT ancestor_chain FROM users WHERE id = %s",
                        (user['invited_by'],)
                    )
                    inviter = cur.fetchone()
                    if inviter and inviter['ancestor_chain']:
                        chain = [user['id']] + list(inviter['ancestor_chain'])
                    else:
                        chain = [user['id'], user['invited_by']]

                cur.execute(
                    "UPDATE users SET ancestor_chain = %s WHERE id = %s",
                    (chain, user['id'])
                )
                updated += 1

            conn.commit()
            print(f"Migration: Updated ancestor_chain for {updated} users")
    except Exception as e:
        conn.rollback()
        print(f"Migration error: {e}")
    finally:
        self.return_connection(conn)
```

## Update create_user_from_invite (db.py)

```python
def create_user_from_invite(self, email: str, name: str, invited_by: int) -> Optional[int]:
    """Create a new user from an invitation, including ancestor chain"""
    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            # Get inviter's ancestor chain
            cur.execute(
                "SELECT ancestor_chain FROM users WHERE id = %s",
                (invited_by,)
            )
            inviter = cur.fetchone()
            inviter_chain = inviter[0] if inviter and inviter[0] else [invited_by]

            # Insert new user
            cur.execute(
                "INSERT INTO users (email, name, invited_by, invited_at, profile_complete) "
                "VALUES (%s, %s, %s, NOW(), FALSE) RETURNING id",
                (email, name, invited_by)
            )
            user_id = cur.fetchone()[0]

            # Set ancestor chain: [new_user_id] + inviter's chain
            new_chain = [user_id] + list(inviter_chain)
            cur.execute(
                "UPDATE users SET ancestor_chain = %s WHERE id = %s",
                (new_chain, user_id)
            )

            conn.commit()
            return user_id
    except psycopg2.IntegrityError:
        conn.rollback()
        return None
    except Exception as e:
        conn.rollback()
        print(f"Error creating user from invite: {e}")
        return None
    finally:
        self.return_connection(conn)
```

## Proximity function (db.py)

```python
def get_proximity(self, user_a_id: int, user_b_id: int) -> int:
    """Calculate proximity between two users based on invite tree distance"""
    if user_a_id == user_b_id:
        return 0

    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, ancestor_chain FROM users WHERE id IN (%s, %s)",
                (user_a_id, user_b_id)
            )
            rows = cur.fetchall()

            if len(rows) != 2:
                return 9999

            chains = {row[0]: row[1] or [] for row in rows}
            chain_a = chains.get(user_a_id, [])
            chain_b = chains.get(user_b_id, [])

            if not chain_a or not chain_b:
                return 9999

            # Find common ancestor
            chain_b_set = set(chain_b)
            for i, ancestor in enumerate(chain_a):
                if ancestor in chain_b_set:
                    return i + chain_b.index(ancestor)

            return 9999
    except Exception as e:
        print(f"Error calculating proximity: {e}")
        return 9999
    finally:
        self.return_connection(conn)
```

## Sorting in get_recent_tagged_posts (db.py)

The `get_recent_tagged_posts` function calculates proximity for all posts and sorts differently based on content type:

```python
# In get_recent_tagged_posts, after fetching posts:

# Get current user's ancestor chain for proximity sorting
current_chain = []
if current_user_id:
    cur.execute("SELECT ancestor_chain FROM users WHERE id = %s", (current_user_id,))
    result = cur.fetchone()
    if result and result['ancestor_chain']:
        current_chain = result['ancestor_chain']

# Helper to calculate proximity
def calc_proximity(user_chain):
    if not current_chain or not user_chain:
        return 9999
    chain_set = set(current_chain)
    for i, ancestor in enumerate(user_chain):
        if ancestor in chain_set:
            return i + current_chain.index(ancestor)
    return 9999

# Calculate proximity for all posts
for post in posts:
    user_chain = post.get('ancestor_chain') or []
    post['proximity'] = calc_proximity(user_chain)

# Sort based on content type
if tags and "profile" in tags:
    # Profiles: proximity first, then activity
    posts.sort(key=lambda p: (
        p['proximity'],
        p.get('last_activity') is None,
        -(p.get('last_activity').timestamp() if p.get('last_activity') else 0)
    ))
    posts = posts[:limit]
else:
    # Posts/queries: date (day) first, proximity as tiebreaker within same day
    def get_date_key(p):
        created = p.get('created_at')
        if created is None:
            return (1, None, 9999)  # None dates sort last
        # Sort by date (newest first), then proximity (closest first)
        return (0, -created.toordinal(), p['proximity'])
    posts.sort(key=get_date_key)
```

## Call migration on startup (app.py)

```python
# In startup health checks section:
logger.info("[HEALTH] Running migrations...")
try:
    db.migrate_add_clip_offsets()
    db.migrate_add_ancestor_chains()
    logger.info("[HEALTH] Migrations complete")
except Exception as e:
    logger.warning(f"[HEALTH] Migration warning: {e}")
```

## Update API endpoints (app.py)

### /api/users/recent
```python
@app.route('/api/users/recent', methods=['GET'])
def get_recent_users():
    """Get users ordered by proximity to current user, then by activity"""
    try:
        email = request.args.get('email', '').strip().lower()
        current_user_id = None
        if email:
            current_user = db.get_user_by_email(email)
            if current_user:
                current_user_id = current_user['id']

        users = db.get_recent_users(current_user_id=current_user_id)
        return jsonify({'status': 'success', 'posts': users})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500
```

### /api/posts/recent-tagged
```python
@app.route('/api/posts/recent-tagged', methods=['GET'])
def get_recent_tagged_posts():
    # ... existing parameter parsing ...

    # Get current user ID for proximity sorting
    current_user_id = None
    if user_email:
        user = db.get_user_by_email(user_email)
        if user:
            current_user_id = user['id']

    posts = db.get_recent_tagged_posts(
        tags=tags,
        user_id=user_id,
        limit=limit,
        current_user_email=user_email,
        after=after,
        current_user_id=current_user_id  # Added for proximity
    )
    return jsonify({'status': 'success', 'posts': posts})
```
