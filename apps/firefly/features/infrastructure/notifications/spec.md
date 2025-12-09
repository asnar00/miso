# notifications
*alerting users to new content via push notifications and toolbar badges*

The notification system alerts users when new content is available through two mechanisms: push notifications (alerts when the app isn't open) and toolbar badges (indicators when the app is open).

## Push Notifications

Real-time alerts that appear on your phone's lock screen and notification center, even when the app is closed. The app icon also shows a badge when there are unread notifications.

**Three notification types:**

- **New post**: When someone creates a post, you see "New post from [name]"
- **Query match**: When a new post matches one of your saved searches, you see "New match for '[search name]'"
- **New user**: When someone completes their profile and joins, you see "[name] just joined"

**Who receives notifications:**

Everyone receives notifications except the person who triggered them. If a single post triggers both "new post" and "query match" for you, you receive one combined notification rather than two separate ones.

**App icon badge:**

The app icon shows a badge (number 1) whenever any toolbar button has a notification dot. The badge is cleared when all toolbar dots are gone.

## Live Updates

When a push notification arrives while you're using the app:
- The notification banner appears at the top
- New content is automatically fetched and added to the top of the relevant list
- If you're not viewing an expanded post, the list scrolls to show the new content
- If you're viewing or editing a post, the list updates silently without disturbing you

## Permission Request

When you first open the app, it asks permission to send notifications. You can choose to allow or deny. If denied, you won't receive push notifications but the app works normally otherwise.

## In-App Toolbar Badges

When the app is open, small red dots appear on toolbar icons to indicate new content:

- **Posts icon**: New posts from other users
- **Search icon**: New matches on your saved searches
- **Users icon**: New members who joined

These badges disappear when you tap the corresponding toolbar button to view that content.
