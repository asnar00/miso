# explore-tree implementation (iOS)

## Post Model Changes

**File**: `Post.swift`

Added `childCount` property:

```swift
struct Post: Codable, Identifiable {
    // ... existing properties ...
    let childCount: Int?

    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case childCount = "child_count"
    }
}
```

**Location**: Post.swift:18

## UI Implementation

**File**: `PostsView.swift`

### Button UI

Added button within ZStack wrapper around post card (PostCardView.swift:135):

```swift
var body: some View {
    ZStack(alignment: .trailing) {
        Group {
            // ... existing post card view ...
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }

        // Show play button if post has children and is expanded
        if isExpanded, let childCount = post.childCount, childCount > 0 {
            Button(action: viewChildren) {
                Image(systemName: "play.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white))
                    .shadow(radius: 2)
            }
            .offset(x: 16)  // Position to overlap right edge
        }
    }
}
```

### Dummy Action Function

Added placeholder function (PostsView.swift:80):

```swift
// Dummy function to view children
func viewChildren() {
    Logger.shared.info("[PostCardView] View children button tapped for post \(post.id): \(post.title)")
    print("[PostCardView] View children button tapped for post \(post.id): \(post.title)")
}
```

## Server API Changes

**File**: `db.py`

Updated `get_recent_posts` query to include child count (db.py:310):

```python
def get_recent_posts(self, limit: int = 50) -> List[Dict[str, Any]]:
    """Get most recent posts with child counts"""
    conn = self.get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
                       p.created_at, p.timezone, p.location_tag, p.ai_generated,
                       u.email as author_name,
                       COUNT(children.id) as child_count
                FROM posts p
                LEFT JOIN users u ON p.user_id = u.id
                LEFT JOIN posts children ON children.parent_id = p.id
                GROUP BY p.id, u.email
                ORDER BY p.created_at DESC
                LIMIT %s
                """,
                (limit,)
            )
            return cur.fetchall()
    except Exception as e:
        print(f"Error getting recent posts: {e}")
        return []
    finally:
        self.return_connection(conn)
```

## Testing

1. **Verify API returns child_count**:
   ```bash
   curl -s http://185.96.221.52:8080/api/posts/recent?limit=10 | \
     python3 -c "import sys, json; [print(f\"{p['id']}: child_count={p['child_count']}\") for p in json.load(sys.stdin)['posts'][:5]]"
   ```

2. **Test on device**:
   - Open app and view posts
   - Expand "test post" (post #6, which has 2 children)
   - Should see white circular button with ▶︎ icon on right edge
   - Tap button
   - Check device logs for: `[PostCardView] View children button tapped for post 6: test post`

3. **Verify button doesn't show on posts without children**:
   - Expand other posts (like "beer", "cherry pie")
   - Button should NOT appear on these posts (child_count = 0)

## Build and Deploy

```bash
cd /Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/ios
./install-device.sh
```

Total build + deploy time: ~10 seconds
