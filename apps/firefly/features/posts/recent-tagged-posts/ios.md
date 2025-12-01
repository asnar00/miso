# iOS Implementation: Recent Tagged Posts

## Overview

iOS implementation of unified recent-tagged-posts feature using SwiftUI.

## Data Structures

```swift
// In PostsListView.swift
enum ViewMode {
    case recent
    case recentUsers
    case recentTagged(tags: [String], byUser: String)  // NEW
    case search(query: String)
    case childPosts(parentId: Int)
}
```

## API Request

```swift
// In PostsListView.swift - fetchPosts() function

func fetchPosts() async {
    isLoading = true
    errorMessage = nil

    guard let baseUrl = URL(string: "http://185.96.221.52:8080") else { return }

    var urlString = ""

    switch mode {
    case .recentTagged(let tags, let byUser):
        // Build query string
        var components = URLComponents(url: baseUrl.appendingPathComponent("/api/posts/recent-tagged"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        // Add tags parameter (empty array means omit parameter)
        if !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }

        // Add by_user parameter
        queryItems.append(URLQueryItem(name: "by_user", value: byUser))

        components.queryItems = queryItems
        urlString = components.url!.absoluteString

    // ... other cases
    }

    // Rest of fetch logic
}
```

## Loading Message

```swift
// In PostsListView.swift - loading view

private var loadingMessage: String {
    switch mode {
    case .recentTagged(let tags, _):
        if tags.contains("profile") {
            return "Loading users..."
        } else if tags.contains("query") {
            return "Loading queries..."
        } else {
            return "Loading posts..."
        }
    case .recent:
        return "Loading posts..."
    case .recentUsers:
        return "Loading users..."
    case .search:
        return "Searching..."
    case .childPosts:
        return "Loading posts..."
    }
}
```

## App Entry Point

```swift
// In NoobTestApp.swift - main content view after sign-in

PostsListView(
    mode: .recentTagged(tags: ["profile"], byUser: "any"),
    showAddButton: false,
    onNavigateToChildren: { postId in
        navigationPath.append(postId)
    }
)
```

## Migration from Old Endpoints

Remove or update these old implementations:
- `.recent` mode (was using `/api/posts/recent`)
- `.recentUsers` mode (was using `/api/users/recent`)

These can be kept for backward compatibility but should redirect to `.recentTagged`:
- `.recent` → `.recentTagged(tags: ["post"], byUser: "any")`
- `.recentUsers` → `.recentTagged(tags: ["profile"], byUser: "any")`

## Target Files

1. **NoobTest/PostsListView.swift**
   - Add `.recentTagged` case to ViewMode enum
   - Update `fetchPosts()` to handle new mode
   - Update `loadingMessage` computed property

2. **NoobTest/NoobTestApp.swift**
   - Change initial PostsListView to use `.recentTagged(tags: ["profile"], byUser: "any")`

## Complete Implementation

### PostsListView.swift Changes

```swift
// Add to ViewMode enum (around line 15)
enum ViewMode {
    case recent
    case recentUsers
    case recentTagged(tags: [String], byUser: String)
    case search(query: String)
    case childPosts(parentId: Int)
}

// Update fetchPosts() function to add new case (around line 80)
func fetchPosts() async {
    isLoading = true
    errorMessage = nil

    guard let baseUrl = URL(string: "http://185.96.221.52:8080") else { return }

    var urlString = ""

    switch mode {
    case .recentTagged(let tags, let byUser):
        var components = URLComponents(url: baseUrl.appendingPathComponent("/api/posts/recent-tagged"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        if !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }

        queryItems.append(URLQueryItem(name: "by_user", value: byUser))
        components.queryItems = queryItems
        urlString = components.url!.absoluteString

    case .recent:
        urlString = baseUrl.appendingPathComponent("/api/posts/recent").absoluteString
    case .recentUsers:
        urlString = baseUrl.appendingPathComponent("/api/users/recent").absoluteString
    case .search(let query):
        var components = URLComponents(url: baseUrl.appendingPathComponent("/api/posts/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        urlString = components.url!.absoluteString
    case .childPosts(let parentId):
        urlString = baseUrl.appendingPathComponent("/api/posts/\(parentId)/children").absoluteString
    }

    // ... rest of function continues as before
}

// Update loadingMessage (around line 200)
private var loadingMessage: String {
    switch mode {
    case .recentTagged(let tags, _):
        if tags.contains("profile") {
            return "Loading users..."
        } else if tags.contains("query") {
            return "Loading queries..."
        } else {
            return "Loading posts..."
        }
    case .recent:
        return "Loading posts..."
    case .recentUsers:
        return "Loading users..."
    case .search:
        return "Searching..."
    case .childPosts:
        return "Loading posts..."
    }
}
```

### NoobTestApp.swift Changes

```swift
// Update the main content view after sign-in (around line 80)
PostsListView(
    mode: .recentTagged(tags: ["profile"], byUser: "any"),
    showAddButton: false,
    onNavigateToChildren: { postId in
        navigationPath.append(postId)
    }
)
```
