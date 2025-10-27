# image caching
*preload and cache post images for instant display*

When Firefly fetches posts from the server, it immediately begins loading images in the background so they're ready when you need them.

The first post's image loads right away - you won't see the posts list until that first image is ready. This ensures there's never a blank space at the top of your feed.

While you're reading that first post, Firefly quietly continues loading images for the remaining posts in the background. By the time you scroll or expand another post, its image is already waiting in memory.

Images are stored as fully decoded pictures in an in-memory cache, not just raw data. This means when you expand a post from compact to full view, the image appears instantly - no loading spinner, no blank space, no delay. The transition feels completely smooth.

The cache holds up to 100 images and uses up to 50MB of memory. This is plenty for scrolling through dozens of posts without having to reload anything.

If you return to a post you've already seen, its image loads instantly from the cache rather than fetching it again from the server. The cache persists while the app is running, making the whole experience feel fast and responsive.

This approach means you never have to wait for images. Whether you're expanding posts, scrolling through your feed, or revisiting content, pictures appear the moment they're needed.
