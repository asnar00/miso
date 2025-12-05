# new-user implementation
*platform-agnostic implementation guide*

## Purpose

Display a welcome screen for first-time users after authentication, then automatically open their profile for editing.

## UI Components

**Layout:**
- Full-screen view with orange/peach background (#FFB27F / rgb(255, 178, 127))
- Vertically centered content
- Logo at top (smaller than sign-in screen)
- Welcome message with user's name in middle
- Action button at bottom

**Elements:**
- Logo: ᕦ(ツ)ᕤ at size 50pt
- Welcome text: "welcome" in large title font
- User name: "[name]!" in large title font below welcome
- Get Started button: Black background, white text, "get started" (lowercase)

## State Management

**Input:**
- `name`: String - User's name from invitation
- `email`: String - User's email address
- `hasSeenWelcome`: Boolean (writable) - Controls whether welcome screen shows
- `shouldEditProfile`: Boolean (writable) - Signals that profile editor should open

**Behavior:**
When "get started" button is tapped:
1. Set `shouldEditProfile` to true
2. Set `hasSeenWelcome` to true
3. App transitions to main content view

## Navigation Flow

The app shows this screen when:
- User IS authenticated AND
- User IS a new user (first device registration) AND
- User HAS NOT seen welcome screen yet

After button tap:
1. `hasSeenWelcome = true` causes transition to ContentView
2. ContentView.onAppear sees `shouldEditProfile = true`
3. ContentView switches to Users tab and sets `editingNewUserProfile = true`
4. PostsListView receives `editCurrentUserProfile = true` and opens profile editor

## Critical Timing Issue

The `editCurrentUserProfile` binding must be checked in **both** places:
1. `onChange(of: editCurrentUserProfile)` - for when value changes after view exists
2. `onAppear` - for when view is created with value already true

This is because ContentView sets the flag before the Users PostsListView is created (data is still loading). When the view appears, the value is already true, so onChange never fires.

## Profile Creation

Profiles are created during the invite process, not here. See `users/invite` feature.

## Incomplete Profile Filtering

Server filters profile queries to hide incomplete profiles from other users:
- Profile is "complete" if summary OR body has content
- Current user's profile always shows regardless of completeness
- Filter applied in `get_recent_tagged_posts` when `tags` includes "profile"

SQL condition:
```sql
(COALESCE(p.summary, '') != '' OR COALESCE(p.body, '') != '' OR LOWER(u.email) = current_user_email)
```

## UI Automation

Register the get started button for automated testing:
- ID: `newuser-getstarted`
- Action: Calls getStarted() function
