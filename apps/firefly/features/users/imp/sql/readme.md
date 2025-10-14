# Users SQL Schema

*Database schema for Firefly user accounts*

## Overview

The `users` table stores basic account information for people using Firefly. Each user is identified by their email address and can have multiple devices associated with their account.

## Table Structure

```sql
users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    device_ids      TEXT[] DEFAULT ARRAY[]::TEXT[]
)
```

## Fields

### id
- Type: `SERIAL PRIMARY KEY`
- Auto-incrementing unique identifier for each user
- Used as foreign key in posts table

### email
- Type: `VARCHAR(255) UNIQUE NOT NULL`
- User's email address
- Must be unique across all users
- Used for signup and login verification

### created_at
- Type: `TIMESTAMP WITH TIME ZONE`
- Account creation timestamp in UTC
- Automatically set on insert

### device_ids
- Type: `TEXT[]` (array)
- List of device IDs associated with this user account
- Allows users to access their account from multiple devices
- Empty array by default

## Indexes

```sql
CREATE INDEX idx_users_email ON users(email);
```

Fast lookup by email address for login/signup operations.

## Common Queries

### Create a new user
```sql
INSERT INTO users (email)
VALUES ('user@example.com')
RETURNING id;
```

### Get user by email
```sql
SELECT id, email, created_at, device_ids
FROM users
WHERE email = 'user@example.com';
```

### Get user by ID
```sql
SELECT id, email, created_at, device_ids
FROM users
WHERE id = 123;
```

### Add device to user
```sql
UPDATE users
SET device_ids = array_append(device_ids, 'device-uuid-here')
WHERE id = 123
AND NOT ('device-uuid-here' = ANY(device_ids));
```

Note: The `NOT (... = ANY(device_ids))` check prevents duplicate device IDs.

### Check if device belongs to user
```sql
SELECT id, email
FROM users
WHERE 'device-uuid-here' = ANY(device_ids);
```

### Remove device from user
```sql
UPDATE users
SET device_ids = array_remove(device_ids, 'device-uuid-here')
WHERE id = 123;
```

### Count total users
```sql
SELECT COUNT(*) FROM users;
```

### Recent users
```sql
SELECT id, email, created_at
FROM users
ORDER BY created_at DESC
LIMIT 50;
```

## Design Decisions

### Why email as identifier?
- Simple signup process (just email + verification code)
- No passwords to manage
- Users already familiar with their email address
- Unique and persistent across sessions

### Why store device_ids as array?
- Users can authenticate from multiple devices (phone, tablet, etc.)
- Simple structure without need for separate devices table
- Easy to check if a device belongs to a user
- PostgreSQL array operations are efficient for small arrays

### Why no password field?
- Firefly uses email-based authentication with verification codes
- Reduces security risks (no password storage/hashing needed)
- Simpler user experience
- If password auth needed later, can add a `password_hash` field

## Relationships

```
users (1) ─────< (*) posts
     └─> One user can have many posts
```

See `posts/imp/sql/schema.sql` for the posts table structure.

## Migration Notes

### Adding this table to existing database
```sql
-- Run schema.sql
\i users/imp/sql/schema.sql

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE users TO firefly_user;
GRANT ALL PRIVILEGES ON SEQUENCE users_id_seq TO firefly_user;
```

### Dropping and recreating
```sql
-- WARNING: Destroys all user data and cascade deletes posts
DROP TABLE IF EXISTS users CASCADE;

-- Recreate
\i users/imp/sql/schema.sql
```

## Utilities

### List Users Script

A Python utility to display all users in the database:

**Location**: `users/imp/sql/list-users.py`

**Quick Usage** (with shell wrapper):
```bash
# Uses default connection settings
./list-users.sh
```

**Direct Usage**:
```bash
# Set environment variables if needed
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=firefly
export DB_USER=firefly_user
export DB_PASSWORD=firefly_pass

# Run Python script directly
python3 list-users.py
```

**Example output**:
```
ID       Email                                    Created                    Devices
==================================================================================
4        carol@example.com                        2025-10-13 17:35:59 UTC    0
3        bob@example.com                          2025-10-13 17:35:59 UTC    2
2        alice@example.com                        2025-10-13 17:35:45 UTC    1

Total users: 3
```

Shows all users sorted by creation date (most recent first) with:
- User ID
- Email address
- Creation timestamp
- Number of associated devices
