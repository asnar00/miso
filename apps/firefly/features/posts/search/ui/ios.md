# Search UI - iOS Implementation

## Component: FloatingSearchBar

**File**: `apps/firefly/product/client/imp/ios/NoobTest/FloatingSearchBar.swift`

**Purpose**: Floating search bar overlay that appears at bottom of screen

## Implementation

```swift
import SwiftUI

struct FloatingSearchBar: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    let onSearch: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 18))

            // Text field
            TextField("Search posts...", text: $searchText)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { newValue in
                    if !newValue.isEmpty {
                        // Debounce search
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if searchText == newValue {
                                onSearch(newValue)
                            }
                        }
                    } else {
                        onClear()
                    }
                }

            // Clear button
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onClear()
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .frame(maxWidth: 600)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}
```

## Integration into ContentView

**File**: `apps/firefly/product/client/imp/ios/NoobTest/ContentView.swift`

Add state variables:
```swift
@State private var searchText = ""
@State private var searchResults: [Post] = []
@State private var isSearching = false
```

Update body to include overlay:
```swift
var body: some View {
    ZStack {
        // Existing content (PostsListView)
        if isSearching && !searchResults.isEmpty {
            PostsListView(posts: searchResults, ...)
        } else {
            PostsListView(posts: recentPosts, ...)
        }

        // Floating search bar overlay
        VStack {
            Spacer()
            FloatingSearchBar(
                searchText: $searchText,
                onSearch: { query in
                    performSearch(query)
                },
                onClear: {
                    isSearching = false
                    searchResults = []
                }
            )
        }
    }
}

func performSearch(_ query: String) {
    guard !query.isEmpty else { return }

    isSearching = true

    let urlString = "\(Config.serverURL)/api/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=20"

    guard let url = URL(string: urlString) else { return }

    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data else { return }

        do {
            let results = try JSONDecoder().decode([Post].self, from: data)
            DispatchQueue.main.async {
                self.searchResults = results
            }
        } catch {
            print("Error decoding search results: \(error)")
        }
    }.resume()
}
```

## Patching Instructions

1. Create new file `FloatingSearchBar.swift`
2. Add to Xcode project using `ios-add-file` skill or manual project.pbxproj editing
3. In `ContentView.swift`:
   - Add state variables at top
   - Wrap existing content in ZStack
   - Add FloatingSearchBar overlay at bottom of ZStack
   - Add performSearch function

## Testing

1. Deploy to device
2. Verify search bar appears at bottom
3. Tap and type search query
4. Verify results appear after 0.5s
5. Tap X to clear and return to recent posts
