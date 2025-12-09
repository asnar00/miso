# notifications - pseudocode
*unified polling and badge mechanism*

## Server: Unified Poll Endpoint

**Endpoint**: `POST /api/notifications/poll`

```
function poll_notifications(request_body) -> NotificationState:
    user_email = request_body.user_email
    query_ids = request_body.query_ids or []
    last_viewed_users = request_body.last_viewed_users  // ISO timestamp string
    last_viewed_posts = request_body.last_viewed_posts  // ISO timestamp string

    result = {
        query_badges: {},
        has_new_users: false,
        has_new_posts: false
    }

    // 1. Check query badges (if any query_ids provided)
    if query_ids is not empty and user_email:
        result.query_badges = get_has_new_matches_bulk(user_email, query_ids)
        // Returns {query_id: has_new_matches} for each query

    // 2. Check for new users (if timestamp provided)
    if last_viewed_users:
        count = database.count("""
            SELECT COUNT(*) FROM users
            WHERE profile_complete = TRUE
            AND profile_completed_at > %s
        """, [last_viewed_users])
        result.has_new_users = count > 0

    // 3. Check for new posts by other users (if timestamp and email provided)
    if last_viewed_posts and user_email:
        count = database.count("""
            SELECT COUNT(*) FROM posts p
            JOIN users u ON p.user_id = u.id
            WHERE p.template_name = 'post'
            AND p.created_at > %s
            AND u.email != %s
        """, [last_viewed_posts, user_email])
        result.has_new_posts = count > 0

    return result
```

## Client: Single Poll Function

```
function ContentView:
    state hasSearchBadge: bool = false
    state hasUsersBadge: bool = false
    state hasPostsBadge: bool = false
    state pollingTimer: Timer = null

    const POLL_INTERVAL = 5.0  // seconds
    const serverURL = "http://185.96.221.52:8080"

    function pollAllBadges():
        // Gather all data for single request
        userEmail = Storage.getLoginState().email
        if not userEmail:
            return

        // Get query IDs from loaded search posts
        queryIds = searchPosts.filter(p => p.template == "query").map(p => p.id)

        // Get last viewed timestamps
        lastViewedUsers = Storage.getString("last_viewed_users") ?? ""
        lastViewedPosts = Storage.getString("last_viewed_posts") ?? ""

        // Build request
        body = {
            "user_email": userEmail,
            "query_ids": queryIds,
            "last_viewed_users": lastViewedUsers,
            "last_viewed_posts": lastViewedPosts
        }

        // Single HTTP request
        response = POST(serverURL + "/api/notifications/poll", body)

        // Update all badge states from response
        if response.query_badges:
            hasSearchBadge = any(response.query_badges.values())

        hasUsersBadge = response.has_new_users ?? false
        hasPostsBadge = response.has_new_posts ?? false

    on_appear:
        // Initialize timestamps if not set
        if Storage.getString("last_viewed_users") == null:
            Storage.set("last_viewed_users", now().isoString)
        if Storage.getString("last_viewed_posts") == null:
            Storage.set("last_viewed_posts", now().isoString)

        pollAllBadges()  // Poll immediately
        pollingTimer = Timer.repeat_every(POLL_INTERVAL, pollAllBadges)

    on_disappear:
        pollingTimer.invalidate()
```

## Client: Badge Clearing

```
function onPostsTabSelected():
    hasPostsBadge = false
    Storage.set("last_viewed_posts", now().isoString)

function onUsersTabSelected():
    hasUsersBadge = false
    Storage.set("last_viewed_users", now().isoString)
```

## Badge Visual Specs

```
NotificationBadge:
    diameter: 10pt
    color: Color.red
    outline: 2pt white stroke
    position: top-right corner of parent button
    offset: (x: 2, y: -2) from corner
```

## Patching Instructions

### Server (Python)

1. **app.py**:
   - Add `POST /api/notifications/poll` endpoint
   - Checks query badges, new users, and new posts in single request
   - Returns combined response with all badge states

### Client (iOS)

1. **ContentView.swift**:
   - Add state: `hasPostsBadge`, `hasUsersBadge`, `hasSearchBadge`
   - Add `pollAllBadges()` function that sends single POST request
   - Start 5-second polling timer on appear
   - Pass badge states to Toolbar component
   - Clear badges and update timestamps when tabs are selected

2. **Toolbar.swift**:
   - Add `showPostsBadge`, `showSearchBadge`, `showUsersBadge` parameters
   - Pass `showBadge` to each ToolbarButton
   - ToolbarButton shows red dot overlay when `showBadge` is true
