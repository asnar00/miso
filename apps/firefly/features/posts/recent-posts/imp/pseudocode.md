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
state isLoadingPosts: Bool = false
state postsError: String? = nil
state posts: Array<Post> = []

function fetchRecentPosts():
  isLoadingPosts = true
  postsError = nil

  fetchRecentPosts(result):
    if result is success:
      fetchedPosts = result.posts

      // Preload first image before displaying
      preloadImagesOptimized(fetchedPosts):
        posts = fetchedPosts
        isLoadingPosts = false

    else if result is failure:
      postsError = result.error.description
      isLoadingPosts = false
```

**Key decisions**:
- App-level state management in NoobTestApp (not in PostsView)
- Posts are fetched once at app startup and passed to PostsView as initialPosts
- This prevents double-loading when navigating between views
- Set loading state immediately before API call
- Clear any previous error messages
- Preload first image before showing posts for instant display

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

## Loading Screen UI

```
if isLoadingPosts:
  display turquoise background (RGB 64/255, 224/255, 208/255)
  display black "ᕦ(ツ)ᕤ" logo (font size = screen width / 12)
  display "Loading posts..." message below logo with spinner
else if postsError exists:
  display turquoise background
  display error message
  display retry button
else:
  display PostsView with posts
```

**Key specifications**:
- Turquoise background: RGB(64, 224, 208)
- Logo: "ᕦ(ツ)ᕤ" in black, size = screen width ÷ 12
- Logo positioned above loading message with spacing

## Initial Load Trigger

```
on app startup (after authentication):
  if posts array is empty and not currently loading:
    fetchRecentPosts()
```

Automatically fetch posts when the app first starts up after sign-in.
