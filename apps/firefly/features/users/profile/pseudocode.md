# Profile Feature - Pseudocode

## Overview

Every user has a profile page that is essentially a special post. The profile post is distinguished by having `template_name = 'profile'`. Profile posts can have children (user's posts attached to their profile).

## Data Model

**Profile Post Structure:**
- `template_name`: 'profile' (identifies this as a profile post)
- `parent_id`: -1 (by convention, profile posts are root-level)
- `title`: User's name
- `summary`: User's profession/mission/tagline
- `body`: Up to 300 words of text (whatever the user wants)
- `image_url`: Optional photograph
- `user_id`: Links to the user who owns this profile
- `child_count`: Number of posts attached to this profile (calculated dynamically)

## Functions

### get_user_profile(user_id)
**Purpose:** Fetch a user's profile post

**Process:**
1. Query the database for a post where `user_id = user_id` AND `template_name = 'profile'`
2. Calculate child_count using subquery: `(SELECT COUNT(*) FROM posts WHERE parent_id = p.id)`
3. Include template metadata (placeholder_title, placeholder_summary, placeholder_body)
4. If found, return the profile post with all fields including child_count
5. If not found, return None

**IMPORTANT:** Filter by template_name, not parent_id, to avoid returning query posts or other root-level posts that also have parent_id = -1.

### create_profile_post(user_id, title, summary, body, image)
**Purpose:** Create a new profile post for a user

**Process:**
1. Create a post with:
   - `user_id`: The user's ID
   - `parent_id`: -1 (special marker for profiles)
   - `title`: Provided title (user's name)
   - `summary`: Provided summary (profession/mission)
   - `body`: Provided body text
   - `image_url`: Provided image (optional)
   - `timezone`: User's current timezone
   - `ai_generated`: false
2. Return the created post

### update_profile_post(post_id, title, summary, body, image)
**Purpose:** Update an existing profile post

**Process:**
1. Update the post with the given `post_id`
2. Update fields: `title`, `summary`, `body`, `image_url`
3. Return the updated post

## UI Components

### Profile Button Handler
**Trigger:** User taps the profile button in toolbar (person icon)

**Process:**
1. Get current logged-in user's ID
2. Call `get_user_profile(user_id)`
3. If profile exists:
   - Navigate to profile view showing the profile post
4. If profile doesn't exist:
   - Show profile editor to create new profile
   - On save, call `create_profile_post()`

### Profile View
**Purpose:** Display the user's profile post

**Components:**
- Same as regular post view (PostView component)
- Shows title, summary, optional image, body
- Includes "Edit" button (pen icon) at bottom right
- On edit: Opens profile editor with current values

### Profile Editor
**Purpose:** Create or edit a profile post

**Fields:**
- Name (title) - text input
- Tagline (summary) - text input
- Photo (image) - optional image picker
- About (body) - multiline text input, max 300 words

**Actions:**
- Save: Creates or updates profile post
- Cancel: Dismisses editor without saving

## API Endpoints

### GET /api/users/{user_id}/profile
**Purpose:** Get a user's profile post

**Response:**
```json
{
  "status": "success",
  "profile": {
    "id": 123,
    "user_id": 45,
    "parent_id": -1,
    "title": "John Doe",
    "summary": "Software Engineer",
    "body": "I love coding...",
    "image_url": "/uploads/abc123.jpg",
    "created_at": "2025-10-31T12:00:00",
    ...
  }
}
```

**If no profile exists:**
```json
{
  "status": "success",
  "profile": null
}
```

### POST /api/users/profile/create
**Purpose:** Create a new profile post

**Request (multipart/form-data):**
- `email`: User's email
- `title`: User's name
- `summary`: Profession/mission
- `body`: About text
- `image`: Optional photo file

**Response:**
```json
{
  "status": "success",
  "profile": { ...post object... }
}
```

### POST /api/users/profile/update
**Purpose:** Update an existing profile post

**Request (multipart/form-data):**
- `post_id`: Profile post ID
- `email`: User's email (for authentication)
- `title`: Updated name
- `summary`: Updated profession/mission
- `body`: Updated about text
- `image`: Optional new photo file

**Response:**
```json
{
  "status": "success",
  "profile": { ...updated post object... }
}
```

## Patching Instructions

### Server (Python Flask)

**File:** `apps/firefly/product/server/imp/py/app.py`

**Add endpoints:**
1. Add `get_user_profile()` endpoint at line ~375 (after `get_post`)
2. Add `create_profile_post()` endpoint at line ~400 (after `get_post_children`)
3. Add `update_profile_post()` endpoint at line ~425 (after create_profile)

**File:** `apps/firefly/product/server/imp/py/db.py`

**Add database functions:**
1. Add `get_user_profile(user_id)` function around line 250
2. Add `update_post()` function around line 260 (for profile updates)

### iOS Client

**File:** `apps/firefly/product/client/imp/ios/NoobTest/Post.swift`

**Add API methods:**
1. Add `fetchUserProfile(userId:completion:)` to PostsAPI class
2. Add `createProfile(title:summary:body:image:completion:)` to PostsAPI class
3. Add `updateProfile(postId:title:summary:body:image:completion:)` to PostsAPI class

**File:** `apps/firefly/product/client/imp/ios/NoobTest/PostsView.swift`

**Update profile button handler:**
1. In `onProfileButtonTap` closure (line ~75), implement profile navigation logic
2. Add state variable `@State private var showProfileView = false`
3. Add state variable `@State private var profilePost: Post? = nil`
4. On profile button tap: fetch profile, show profile view or editor

**New file:** `apps/firefly/product/client/imp/ios/NoobTest/ProfileView.swift`

**Create profile view:**
1. Use PostView component to display profile
2. Add edit button overlay (pen icon at bottom right)
3. On edit: present ProfileEditor

**New file:** `apps/firefly/product/client/imp/ios/NoobTest/ProfileEditor.swift`

**Create profile editor:**
1. Similar to NewPostEditor but for profiles
2. Fields: name, tagline, photo, about
3. On save: call create or update API
4. On dismiss: close editor

### Android Client (Future)

Similar pattern to iOS implementation.
