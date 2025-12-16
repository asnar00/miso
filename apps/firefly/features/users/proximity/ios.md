# proximity iOS implementation
*client-side changes for proximity-based sorting*

## Overview

The iOS client requires minimal changes for proximity sorting. All proximity calculation happens server-side. The client's only responsibility is to pass the current user's email so the server knows who to calculate proximity relative to.

## Update fetchRecentTaggedPosts (Post.swift)

The `fetchRecentTaggedPosts` function must always pass the `user_email` parameter, not just when fetching the current user's posts:

```swift
func fetchRecentTaggedPosts(tags: [String], byUser: String, after: String? = nil, completion: @escaping (Result<[Post], Error>) -> Void) {
    var components = URLComponents(string: "\(serverURL)/api/posts/recent-tagged")!
    var queryItems: [URLQueryItem] = []

    // Add tags parameter
    if !tags.isEmpty {
        queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
    }

    // Add by_user parameter
    queryItems.append(URLQueryItem(name: "by_user", value: byUser))

    // Always add user_email for proximity-based sorting
    let loginState = Storage.shared.getLoginState()
    if let userEmail = loginState.email {
        queryItems.append(URLQueryItem(name: "user_email", value: userEmail))
    }

    // Add after parameter for incremental fetch
    if let after = after {
        queryItems.append(URLQueryItem(name: "after", value: after))
    }

    components.queryItems = queryItems

    // ... rest of function unchanged
}
```

## Key change

**Before:** `user_email` was only passed when `byUser == "current"` or when tags contained `"profile"`.

**After:** `user_email` is always passed when the user is logged in.

This allows the server to calculate proximity for any list (posts, queries, users) and sort accordingly.

## No other changes needed

The client already:
- Displays posts in whatever order the server returns them
- Does not need to know about proximity values
- Does not perform any sorting client-side

Proximity is entirely a server-side ranking signal.
