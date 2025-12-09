# notifications - pseudocode
*push notifications, live updates, and in-app badge mechanism*

## Data Model

**Users table additions:**
```
apns_device_token: string (nullable)  // APNs device token for push notifications
```

**Server configuration (.env):**
```
APNS_KEY_ID: string           // Key ID from Apple Developer portal
APNS_TEAM_ID: string          // Team ID from Apple Developer portal
APNS_KEY_PATH: string         // Path to .p8 key file
APNS_BUNDLE_ID: string        // App bundle identifier (com.miso.noobtest)
APNS_USE_SANDBOX: bool        // true for development, false for production
```

---

## Push Notification Flow

### 1. Device Token Registration

**Client (on app launch):**
```
function registerForPushNotifications():
    request permission for notifications (alert, badge, sound)

    if granted:
        register with system push service
        receive device token
        send token to server

function onReceivedDeviceToken(token):
    tokenString = convert token to hex string

    POST /api/notifications/register-device
    body: { device_id: currentDeviceId, apns_token: tokenString }
```

**Server endpoint:** `POST /api/notifications/register-device`
```
function register_device(request_body):
    device_id = request_body.device_id
    apns_token = request_body.apns_token

    user = database.get_user_by_device_id(device_id)
    if user:
        database.update_user_apns_token(user.id, apns_token)
        return { status: "ok" }
    else:
        return { status: "error", message: "User not found" }
```

### 2. Sending Push Notifications

**Server: Send push notification using PyAPNs2:**
```
function send_push_notification(device_token: string, title: string, body: string, badge: int = 1):
    payload = Payload(
        alert = PayloadAlert(title=title, body=body),
        badge = badge,
        sound = "default"
    )

    apns_client.send_notification(
        token_hex = device_token,
        notification = Notification(payload=payload),
        topic = APNS_BUNDLE_ID
    )
```

### 3. Notification Triggers

**On new post created:**
```
function on_post_created(post, author):
    if post.template_name != 'post':
        return  // Only notify for regular posts

    // Get all users except author who have APNs tokens
    recipients = database.get_users_with_apns_tokens(exclude_user_id=author.id)

    // Check which recipients have matching queries
    matching_queries = database.get_queries_matching_post(post)
    users_with_matches = { query.user_id: query.title for query in matching_queries }

    for user in recipients:
        if user.id in users_with_matches:
            // Consolidated: mention query match
            query_title = users_with_matches[user.id]
            send_push_notification(
                user.apns_device_token,
                title = "New match",
                body = "'{query_title}' matched a post from {author.name}"
            )
        else:
            // Just new post notification
            send_push_notification(
                user.apns_device_token,
                title = "New post",
                body = "New post from {author.name}"
            )
```

**On user profile completed:**
```
function on_profile_completed(new_user):
    // Get all users except the new user who have APNs tokens
    recipients = database.get_users_with_apns_tokens(exclude_user_id=new_user.id)

    for user in recipients:
        send_push_notification(
            user.apns_device_token,
            title = "New member",
            body = "{new_user.name} just joined"
        )
```

---

## Live Updates (Foreground Push Handling)

### Internal Notification Names
```
pushNotificationReceived     // Posted when push received in foreground
scrollToTopIfNotExpanded     // Posted to trigger scroll after new content loaded
```

### On Push Notification Received in Foreground
```
function onPushNotificationReceived():
    // Show banner, sound, and update badge
    completionHandler([.banner, .sound, .badge])

    // Post internal notification to trigger content refresh
    NotificationCenter.post(name: .pushNotificationReceived)
```

### ContentView Response to Push
```
function onReceivePushNotification():
    fetchNewPosts()
    fetchNewSearches()
    fetchNewUsers()
    pollAllBadges()

    // After 0.5s delay, scroll to top if no post expanded
    after 0.5 seconds:
        NotificationCenter.post(name: .scrollToTopIfNotExpanded)
```

---

## Incremental Fetch with Deduplication

**State tracking:**
```
latestPostTimestamp: string?    // ISO8601 timestamp of newest post
latestSearchTimestamp: string?  // ISO8601 timestamp of newest query
latestUsersTimestamp: string?   // ISO8601 timestamp of newest profile
```

**Incremental fetch function (same pattern for all three types):**
```
function fetchNewPosts():
    if latestPostTimestamp is nil:
        // First load - do full fetch
        fetchMakePostPosts()
        return

    // Fetch only posts newer than our latest
    newPosts = GET /api/posts/recent-tagged?tags=post&after={latestPostTimestamp}

    if newPosts is empty:
        return

    // Filter out posts already in list (deduplication)
    existingIds = Set(makePostPosts.map(p => p.id))
    trulyNewPosts = newPosts.filter(p => !existingIds.contains(p.id))

    if trulyNewPosts is empty:
        return

    // Prepend to existing list
    makePostPosts = trulyNewPosts + makePostPosts

    // Update timestamp
    latestPostTimestamp = trulyNewPosts.first.createdAt
```

**Server: `after` parameter support:**
```
GET /api/posts/recent-tagged?tags=post&after=2024-12-09T18:00:00Z

SQL condition: WHERE p.created_at > {after}
```

---

## Scroll to Top Behavior

**PostsListView response to scrollToTopIfNotExpanded:**
```
function onScrollToTopIfNotExpanded():
    if expandedPostId is nil:
        // No post is expanded, scroll to show new content
        scrollTo(posts.first.id, anchor: .top)
    // If a post IS expanded, do nothing (don't disturb user)
```

---

## App Icon Badge Logic

**On app becoming active:**
```
function onAppBecameActive():
    // Sync app badge with toolbar badge state
    if hasPostsBadge or hasSearchBadge or hasUsersBadge:
        appIconBadgeNumber = 1
    else:
        appIconBadgeNumber = 0

    // Also do incremental fetch if timestamps are set
    if latestPostTimestamp is set: fetchNewPosts()
    if latestSearchTimestamp is set: fetchNewSearches()
    if latestUsersTimestamp is set: fetchNewUsers()
```

---

## In-App Polling (existing)

**Endpoint**: `POST /api/notifications/poll`

```
function poll_notifications(request_body) -> NotificationState:
    user_email = request_body.user_email
    query_ids = request_body.query_ids or []
    last_viewed_users = request_body.last_viewed_users
    last_viewed_posts = request_body.last_viewed_posts

    result = {
        query_badges: {},
        has_new_users: false,
        has_new_posts: false
    }

    // 1. Check query badges
    if query_ids is not empty and user_email:
        result.query_badges = get_has_new_matches_bulk(user_email, query_ids)

    // 2. Check for new users
    if last_viewed_users:
        count = database.count_users_completed_since(last_viewed_users)
        result.has_new_users = count > 0

    // 3. Check for new posts by other users
    if last_viewed_posts and user_email:
        count = database.count_posts_since(last_viewed_posts, exclude_email=user_email)
        result.has_new_posts = count > 0

    return result
```

## Badge Visual Specs

```
NotificationBadge:
    diameter: 10pt
    color: red
    outline: 2pt white stroke
    position: top-right corner of parent button
    offset: (x: 2, y: -2) from corner
```

---

## Patching Instructions

### Server

1. **Database**: Add `apns_device_token` column to users table
2. **Config**: Add APNs credentials to .env file
3. **New module**: `apns_client.py` using PyAPNs2 library
4. **New endpoint**: `POST /api/notifications/register-device`
5. **Modify endpoint**: `GET /api/posts/recent-tagged` - add `after` query parameter
6. **Integration**: Call notification functions after post creation and profile completion

### Client

1. **AppDelegate**: Handle push registration, token callback, foreground notification display
2. **Notification names**: Define `.pushNotificationReceived` and `.scrollToTopIfNotExpanded`
3. **ContentView**: Add `.onReceive` handlers for push notifications and app activation
4. **Incremental fetch**: Add `fetchNewPosts()`, `fetchNewSearches()`, `fetchNewUsers()` with deduplication
5. **Timestamp tracking**: Add state variables for latest timestamps per content type
6. **PostsListView**: Add `.onReceive` handler for scroll-to-top notification
