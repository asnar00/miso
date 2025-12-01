# new-user implementation
*platform-agnostic implementation guide*

## Purpose

Display a welcome screen for first-time users after authentication, introducing them to the app and providing a clear entry point.

## UI Components

**Layout:**
- Full-screen view with turquoise background
- Vertically centered content
- Logo at top
- Welcome message and user email in middle
- Action button at bottom

**Elements:**
- Logo: Large nøøb logo (ᕦ(ツ)ᕤ)
- Welcome text: "welcome" in large bold font
- User email: Display authenticated user's email address
- Get Started button: Primary action button to dismiss welcome screen

## State Management

**Input:**
- `email`: String - User's authenticated email address
- `hasSeenWelcome`: Boolean (writable) - Flag controlling whether this screen is shown

**Behavior:**
- When "Get Started" button is tapped:
  - Set `hasSeenWelcome` to true
  - Navigate to main app content
  - Log the action

## Navigation Flow

The app should show this screen when:
- User IS authenticated AND
- User IS a new user (first device registration) AND
- User HAS NOT seen welcome screen yet (`hasSeenWelcome` is false)

After the button is tapped, the app transitions to the main content view and this screen won't be shown again for this session or future sessions.

## Integration Points

**Called by:** App-level navigation logic after successful authentication

**Modifies:** `hasSeenWelcome` state variable to indicate tutorial completion

**Navigates to:** Main app content (home screen/posts view)

## Design Notes

- Keep the design simple and welcoming
- Use app's primary turquoise color (#40E0D0)
- Logo should be prominent but not overwhelming
- Button should be clearly actionable
- Entire flow should take less than 5 seconds for user to complete
