# recent-posts pseudocode

## API Call

```
function fetchRecentPosts(callback):
  url = serverURL + "/api/posts/recent"

  HTTP GET url:
    on success with postsData:
      posts = parse JSON as array of Post objects
      callback(success: posts)

    on failure with error:
      callback(failure: error)
```

**Key decision**: Use a callback pattern to handle asynchronous HTTP response.

## Post Loading Sequence

```
state isLoading: Bool = false
state errorMessage: String? = nil
state posts: Array<Post> = []

function loadPosts():
  isLoading = true
  errorMessage = nil

  fetchRecentPosts(result):
    if result is success:
      fetchedPosts = result.posts

      // Preload first image before displaying
      preloadImagesOptimized(fetchedPosts):
        posts = fetchedPosts
        isLoading = false

        // Auto-expand first post
        if posts not empty:
          expandedPostIds.add(posts[0].id)

    else if result is failure:
      errorMessage = result.error.description
      isLoading = false
```

**Key decisions**:
- Set loading state immediately before API call
- Clear any previous error messages
- Preload first image before showing posts for instant display
- Auto-expand first post for immediate reading
- Continue loading remaining images in background

## Image Preloading Strategy

```
function preloadImagesOptimized(posts, completion):
  imageUrls = extract all image URLs from posts

  if imageUrls is empty:
    completion()
    return

  firstImageUrl = imageUrls[0]

  // Load first image synchronously
  ImageCache.preload([firstImageUrl]):
    completion()  // Display posts now

    // Load remaining images in background
    if imageUrls.count > 1:
      remainingUrls = imageUrls[1..]
      ImageCache.preload(remainingUrls):
        // Background loading complete
```

**Key decision**: Load first image before displaying feed, then load remaining images in background to balance initial perceived speed with complete experience.

## Initial Load Trigger

```
on view appear:
  loadPosts()
```

Automatically fetch posts when the view first appears.
