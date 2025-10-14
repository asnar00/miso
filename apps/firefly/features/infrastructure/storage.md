# storage
*persistent local data on the device*

Storage keeps data on the device so it survives app restarts. This includes login state, cached content, and media files.

## Current needs

**Login state**: The app needs to remember if you're logged in and what email address you used. When you restart the app, it should already know who you are.

## Future needs

**Database cache**: Copy frequently-accessed posts and user data to the device so the app works offline and loads instantly.

**Media cache**: Store downloaded images locally so they don't need to be re-downloaded every time.

**User preferences**: Settings like notification preferences, theme choices, or other customizations.

## Implementation approach

**Key-value storage** for simple data like login state and preferences. Quick to read and write, perfect for small pieces of data.

**Structured storage** for complex data like cached posts. Allows querying and relationships between data.

**File storage** for media like images and videos. Organized by content type with size management to prevent filling up the device.

All storage is private to the user and cleared when they log out or uninstall the app.
