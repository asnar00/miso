# new-user
*how we welcome new users and guide them to complete their profile*

The new-user screen appears after sign-in for users who haven't completed their profile yet. It welcomes them by name and guides them to set up their profile.

## Welcome Screen

Shows:
- The microclub logo (ᕦ(ツ)ᕤ)
- "welcome" text
- User's name (from their invitation) with exclamation mark
- "get started" button

Background is orange/peach (#FFB27F).

## Get Started Flow

When the user taps "get started":
1. Create a new profile post for the user with their name as the title
2. App switches to the Users tab
3. User's profile opens automatically in edit mode
4. Name field is pre-filled (from invitation)
5. User can add profession, photo, and bio
6. When they tap outside or save, profile is updated

## Profile Creation Timing

The profile is created when the user taps "get started" (not during the invite process). This means:
- No profile exists until the user actively joins
- Profile is created with just their name initially
- Considered "incomplete" until they add summary or body content

## Incomplete Profile Visibility

Incomplete profiles (empty summary AND body) are hidden from other users' views but visible to the profile owner. This prevents blank profiles from cluttering the Users list while still allowing the owner to see and edit their own profile.

## After Setup

The Users page shows all profiles, with the current user's profile visible regardless of completeness.
