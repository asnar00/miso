# recent-users pseudocode

## API Call

```
function fetchRecentUsers(callback):
  url = serverURL + "/api/users/recent"

  HTTP GET url:
    on success with usersData:
      users = parse JSON as array of Post objects (profile posts with parent_id = -1)
      callback(success: users)

    on failure with error:
      callback(failure: error)
```

**Key decision**: Reuse the Post data structure since we're fetching profile posts. The server returns users ordered by last_activity DESC, with each user represented by their profile post.

## User Loading Sequence

```
state isLoadingUsers: Bool = false
state usersError: String? = nil
state users: Array<Post> = []

function fetchRecentUsers():
  isLoadingUsers = true
  usersError = nil

  fetchRecentUsers(result):
    if result is success:
      fetchedUsers = result.users

      // Preload first image before displaying
      preloadImagesOptimized(fetchedUsers):
        users = fetchedUsers
        isLoadingUsers = false

    else if result is failure:
      usersError = result.error.description
      isLoadingUsers = false
```

**Key decisions**:
- App-level state management in NoobTestApp (not in view)
- Users are fetched once at app startup and passed to PostsView as initialPosts
- This prevents double-loading when navigating between views
- Set loading state immediately before API call
- Clear any previous error messages
- Preload first image before showing users for instant display

## Image Preloading Strategy

```
function preloadImagesOptimized(users, completion):
  imageUrls = extract all image URLs from users

  if imageUrls is empty:
    completion()
    return

  firstImageUrl = imageUrls[0]

  // Load first image synchronously
  ImageCache.preload([firstImageUrl]):
    completion()  // Display users now

    // Load remaining images in background
    if imageUrls.count > 1:
      remainingUrls = imageUrls[1..]
      ImageCache.preload(remainingUrls):
        // Background loading complete
```

**Key decision**: Load first image before displaying list, then load remaining images in background to balance initial perceived speed with complete experience.

## Loading Screen UI

```
if isLoadingUsers:
  display turquoise background (RGB 64/255, 224/255, 208/255)
  display black "ᕦ(ツ)ᕤ" logo (font size = screen width / 12)
  display "Loading users..." message below logo with spinner
else if usersError exists:
  display turquoise background
  display error message
  display retry button
else:
  display PostsView with users (no "Add Post" button)
```

**Key specifications**:
- Turquoise background: RGB(64, 224, 208)
- Logo: "ᕦ(ツ)ᕤ" in black, size = screen width ÷ 12
- Logo positioned above loading message with spacing
- Loading message: "Loading users..." (not "Loading posts...")
- No "Add Post" button in this view

## Initial Load Trigger

```
on app startup (after authentication):
  if users array is empty and not currently loading:
    fetchRecentUsers()
```

Automatically fetch users when the app first starts up after sign-in.

## Patching Instructions

**Server (Python)**:
- Create new endpoint `/api/users/recent` in main Flask app
- Query database: SELECT posts WHERE parent_id = -1 ORDER BY users.last_activity DESC
- Join with users table to access last_activity timestamp
- Return array of profile posts in standard Post JSON format

**Client (iOS)**:
- Add `fetchRecentUsers()` function to NoobTestApp
- Change app startup from `fetchRecentPosts()` to `fetchRecentUsers()`
- Update loading state variables: `isLoadingUsers`, `usersError`, `users`
- Pass `showAddButton: false` to PostsView when displaying recent users
- Update loading message from "Loading posts..." to "Loading users..."
