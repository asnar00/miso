# templates iOS implementation

## Post Model

The Post struct includes optional placeholder fields from the templates table:

```swift
struct Post: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let parentId: Int?
    var title: String
    var summary: String
    var body: String
    var imageUrl: String?
    let createdAt: String
    let timezone: String
    let locationTag: String?
    let aiGenerated: Bool
    let authorName: String?
    let authorEmail: String?
    let childCount: Int?

    // Template placeholder fields (optional, from templates table via JOIN)
    let titlePlaceholder: String?
    let summaryPlaceholder: String?
    let bodyPlaceholder: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case parentId = "parent_id"
        case title
        case summary
        case body
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case timezone
        case locationTag = "location_tag"
        case aiGenerated = "ai_generated"
        case authorName = "author_name"
        case authorEmail = "author_email"
        case childCount = "child_count"

        // Template placeholder fields use snake_case from API
        case titlePlaceholder = "placeholder_title"
        case summaryPlaceholder = "placeholder_summary"
        case bodyPlaceholder = "placeholder_body"
    }
}
```

## Using Placeholders in Views

### Text Field with Placeholder

```swift
TextField("", text: $editableTitle,
          prompt: Text(post.titlePlaceholder ?? "Title")
                      .foregroundColor(Color.gray.opacity(0.55)))
    .font(.system(size: 22, weight: .bold))
    .textFieldStyle(.plain)
```

### Summary Field with Placeholder

```swift
TextField("", text: $editableSummary,
          prompt: Text(post.summaryPlaceholder ?? "Summary").italic()
                      .foregroundColor(Color.gray.opacity(0.55)))
    .font(.system(size: 15))
    .italic()
    .textFieldStyle(.plain)
```

### Text Editor with Overlay Placeholder

TextEditor doesn't support the `prompt` parameter, so use ZStack with overlay:

```swift
ZStack(alignment: .topLeading) {
    // Grey background in edit mode
    if isEditing {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
    }

    TextEditor(text: $editableBody)
        .scrollContentBackground(.hidden)
        .frame(width: availableWidth, height: bodyHeight)
        .disabled(!isEditing)

    // Placeholder text overlay (only when editing and empty)
    if isEditing && editableBody.isEmpty {
        Text(post.bodyPlaceholder ?? "Body")
            .foregroundColor(Color.gray.opacity(0.55))
            .padding(.leading, 5)
            .padding(.top, 8)
            .allowsHitTesting(false)  // Let taps pass through to TextEditor
    }
}
```

## Fallback Pattern

Always provide fallback defaults using the nil-coalescing operator:

```swift
// Fallback to standard English labels if template doesn't provide them
let titleLabel = post.titlePlaceholder ?? "Title"
let summaryLabel = post.summaryPlaceholder ?? "Summary"
let bodyLabel = post.bodyPlaceholder ?? "Body"
```

**Why fallbacks are important:**
- Post might reference non-existent template
- LEFT JOIN might return NULL for placeholders
- Makes app resilient to backend issues
- Provides sensible defaults for all users

## API Response Format

The server returns posts with placeholder fields from the templates table:

```json
{
    "id": 22,
    "title": "asnaroo",
    "summary": "fix all the things",
    "body": "I'm a self-taught ninja software confectioner...",
    "template_name": "profile",
    "placeholder_title": "name",
    "placeholder_summary": "mission",
    "placeholder_body": "personal statement",
    "author_name": "asnaroo",
    "author_email": "test@example.com",
    ...
}
```

The iOS Codable system automatically maps:
- `placeholder_title` → `titlePlaceholder`
- `placeholder_summary` → `summaryPlaceholder`
- `placeholder_body` → `bodyPlaceholder`

## Visual Design

### Placeholder Appearance

Placeholder text uses consistent styling across all fields:

```swift
Text(placeholderText)
    .foregroundColor(Color.gray.opacity(0.55))
```

**Opacity**: 0.55 (55%) - darker than default iOS placeholders for better readability
**Color**: Gray
**Positioning**: Inline with field content (not floating labels)

### Edit Mode Backgrounds

All editable fields get a grey background to indicate edit mode:

```swift
RoundedRectangle(cornerRadius: 8)
    .fill(Color.gray.opacity(0.2))
```

**Background opacity**: 0.2 (20%)
**Corner radius**: 8pt
**Applied to**: Title, summary, and body fields individually

## Example: Different Templates in Use

### Standard Post (template: "post")

```swift
// User sees:
TextField("", text: $title, prompt: Text("Title"))      // "Title"
TextField("", text: $summary, prompt: Text("Summary"))  // "Summary"
TextEditor with overlay: "Body"                         // "Body"
```

### Profile Post (template: "profile")

```swift
// User sees:
TextField("", text: $title, prompt: Text("name"))              // "name"
TextField("", text: $summary, prompt: Text("mission"))         // "mission"
TextEditor with overlay: "personal statement"                  // "personal statement"
```

Same Swift code, different user experience based on template data.

## Integration Points

### PostView

PostView.swift uses placeholders in edit mode:

```swift
struct PostView: View {
    let post: Post
    @State private var isEditing: Bool = false
    @State private var editableTitle: String = ""
    @State private var editableSummary: String = ""
    @State private var editableBody: String = ""

    var body: some View {
        VStack {
            if isEditing {
                // Title field with custom placeholder
                TextField("", text: $editableTitle,
                          prompt: Text(post.titlePlaceholder ?? "Title")
                                      .foregroundColor(Color.gray.opacity(0.55)))

                // Summary field with custom placeholder
                TextField("", text: $editableSummary,
                          prompt: Text(post.summaryPlaceholder ?? "Summary").italic()
                                      .foregroundColor(Color.gray.opacity(0.55)))

                // Body editor with overlay placeholder
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editableBody)
                    if editableBody.isEmpty {
                        Text(post.bodyPlaceholder ?? "Body")
                            .foregroundColor(Color.gray.opacity(0.55))
                            .padding(.leading, 5)
                            .padding(.top, 8)
                    }
                }
            } else {
                // Display mode - no placeholders shown
                Text(post.title)
                Text(post.summary)
                Text(post.body)
            }
        }
    }
}
```

### NewPostView

NewPostView.swift could also use templates for new post creation:

```swift
struct NewPostView: View {
    let templateName: String = "post"  // Could be selectable
    @State private var template: Template?
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var body: String = ""

    var body: some View {
        VStack {
            TextField("", text: $title,
                      prompt: Text(template?.titlePlaceholder ?? "Title"))

            TextField("", text: $summary,
                      prompt: Text(template?.summaryPlaceholder ?? "Summary"))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $body)
                if body.isEmpty {
                    Text(template?.bodyPlaceholder ?? "Body")
                        .foregroundColor(Color.gray.opacity(0.55))
                }
            }
        }
        .onAppear {
            fetchTemplate(templateName)
        }
    }
}
```

## Template Model (Future)

If the app needs to work with templates directly:

```swift
struct Template: Codable, Identifiable {
    var id: String { name }  // name is the primary key
    let name: String
    let placeholderTitle: String
    let placeholderSummary: String
    let placeholderBody: String

    enum CodingKeys: String, CodingKey {
        case name
        case placeholderTitle = "placeholder_title"
        case placeholderSummary = "placeholder_summary"
        case placeholderBody = "placeholder_body"
    }
}

struct TemplatesResponse: Codable {
    let status: String
    let templates: [Template]
}
```

## Fetching Templates (Future API)

If templates become fetchable via API:

```swift
func fetchTemplates() async throws -> [Template] {
    let url = URL(string: "\(serverURL)/api/templates")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TemplatesResponse.self, from: data)
    return response.templates
}
```

## Template Selection UI (Future)

Could allow users to choose template when creating posts:

```swift
struct TemplatePicker: View {
    @Binding var selectedTemplate: String
    let templates: [Template]

    var body: some View {
        Picker("Post Type", selection: $selectedTemplate) {
            ForEach(templates) { template in
                Text(template.name.capitalized).tag(template.name)
            }
        }
        .pickerStyle(.segmented)
    }
}
```

## Testing

### Test Different Templates

```swift
// Create test posts with different templates
let standardPost = Post(
    id: 1,
    title: "My First Post",
    titlePlaceholder: "Title",
    summaryPlaceholder: "Summary",
    bodyPlaceholder: "Body"
)

let profilePost = Post(
    id: 2,
    title: "asnaroo",
    titlePlaceholder: "name",
    summaryPlaceholder: "mission",
    bodyPlaceholder: "personal statement"
)

// Verify placeholders display correctly in edit mode
```

### Test Fallback Behavior

```swift
// Post with nil placeholders should use defaults
let postWithoutTemplate = Post(
    id: 3,
    title: "Test",
    titlePlaceholder: nil,
    summaryPlaceholder: nil,
    bodyPlaceholder: nil
)

// Should display "Title", "Summary", "Body"
```

## Migration Notes

When updating existing iOS app to support templates:

1. **Update Post Model**: Add optional placeholder fields and CodingKeys
2. **Update Views**: Use `post.titlePlaceholder ?? "Title"` pattern
3. **Test with Server**: Verify API returns placeholder fields
4. **Handle Nulls**: Ensure fallback to defaults works
5. **Visual Verification**: Check placeholder opacity (0.55) looks good
6. **Test Edit Mode**: Verify placeholders disappear when typing

## Key Implementation Details

1. **Optional Fields**: Placeholder fields are optional (`String?`) because they come from a LEFT JOIN that might return NULL

2. **CodingKeys Mapping**: API uses snake_case (`placeholder_title`), Swift uses camelCase (`titlePlaceholder`)

3. **Fallback Pattern**: Always use `??` operator to provide sensible defaults

4. **TextEditor Limitation**: TextEditor doesn't support `prompt` parameter, requires ZStack overlay approach

5. **Opacity Consistency**: Use 0.55 opacity for all placeholder text across the app

6. **No Local Storage**: Templates come from server, not stored locally in the app

7. **Backward Compatible**: Nil placeholders fall back to English defaults, so old servers work

## Accessibility

Placeholders should be accessible to VoiceOver users:

```swift
TextField("", text: $title,
          prompt: Text(post.titlePlaceholder ?? "Title"))
    .accessibilityLabel(post.titlePlaceholder ?? "Title")
    .accessibilityHint("Enter the \(post.titlePlaceholder?.lowercased() ?? "title") for this post")
```

## Localization (Future)

Templates are currently English-only. For localization:

```swift
// Could fetch templates based on user's locale
func fetchTemplates(locale: String) async throws -> [Template] {
    let url = URL(string: "\(serverURL)/api/templates?locale=\(locale)")!
    // ...
}

// Or use localized fallbacks
let titleLabel = post.titlePlaceholder ?? NSLocalizedString("Title", comment: "Post title field")
```

## Performance

Templates add minimal overhead:
- No additional network requests (included in post queries)
- No complex parsing (simple strings)
- No caching needed (part of post data)
- Falls back gracefully if missing
