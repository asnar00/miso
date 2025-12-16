# proximity pseudocode
*data structures and algorithms for user proximity*

## Data model

Add to users table:
```
ancestor_chain: INTEGER[]  -- array of user IDs from self to root
                           -- e.g., [5, 3, 1] means user 5, invited by 3, invited by 1 (root)
```

## Computing ancestor chain

When a user is created:
```
function compute_ancestor_chain(new_user_id, inviter_id):
    if inviter_id is null:
        return [new_user_id]  # Root user
    else:
        inviter_chain = get_user_ancestor_chain(inviter_id)
        return [new_user_id] + inviter_chain
```

## Computing proximity

```
function calc_proximity(current_chain, user_chain):
    if not current_chain or not user_chain:
        return 9999  # No chain = sort last

    chain_set = set(current_chain)
    for i, ancestor in enumerate(user_chain):
        if ancestor in chain_set:
            # Found common ancestor
            return i + current_chain.index(ancestor)

    return 9999  # No common ancestor
```

## Sorting rules

**Users/Profiles:**
```
sort by:
    1. proximity (ascending) - closest first
    2. last_activity (descending) - most active first
```

**Posts/Queries:**
```
sort by:
    1. date only, ignoring time (descending) - newest day first
    2. proximity (ascending) - closest first within same day
```

The date-only comparison uses `created_at.toordinal()` to compare calendar days, not timestamps. This means all posts from "today" are grouped together and sorted by proximity, then all posts from "yesterday", etc.

## Migration

For existing users without ancestor_chain:
```
function migrate_ancestor_chains():
    for each user ordered by created_at (oldest first):
        if user.ancestor_chain is null:
            if user.invited_by is null:
                user.ancestor_chain = [user.id]
            else:
                inviter = get_user(user.invited_by)
                user.ancestor_chain = [user.id] + inviter.ancestor_chain
            save(user)
```

## Patching instructions

### Server (db.py)
1. Add `migrate_add_ancestor_chains()` function - adds column and populates existing users
2. Update `create_user_from_invite()` to set ancestor_chain for new users
3. Add `get_proximity()` function for standalone proximity calculation
4. Update `get_recent_users()` to accept current_user_id and sort by proximity
5. Update `get_recent_tagged_posts()` to:
   - Accept current_user_id parameter
   - Include ancestor_chain in query
   - Calculate proximity for all posts
   - Sort profiles by proximity, posts/queries by date then proximity

### Server (app.py)
6. Call `db.migrate_add_ancestor_chains()` on startup
7. Update `/api/users/recent` to extract current_user_id from email param
8. Update `/api/posts/recent-tagged` to pass current_user_id to db function

### iOS Client (Post.swift)
9. Update `fetchRecentTaggedPosts()` to always pass user_email parameter for proximity sorting
