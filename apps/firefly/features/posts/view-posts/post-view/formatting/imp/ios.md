# formatting iOS implementation

## SwiftUI Font and Style Application

```swift
// Title (same in both compact and expanded states)
Text(post.title)
    .font(.system(size: 24, weight: .bold))
    .foregroundColor(.black)

// Summary
Text(post.summary)
    .font(.subheadline)
    .italic()
    .foregroundColor(.black.opacity(0.8))

// Metadata
Text(metadata)
    .font(.caption)
    .foregroundColor(.black.opacity(0.6))
```

## Background and Card Styling

```swift
.background(Color(red: 64/255, green: 224/255, blue: 208/255))  // Turquoise background
    .ignoresSafeArea()

.padding()  // 8pt spacing inside card
.background(Color.white.opacity(0.9))
.cornerRadius(12)
.shadow(radius: 2)
```

## VStack and HStack Spacing

```swift
VStack(spacing: 8) {  // 8pt between cards
    ForEach(posts) { post in
        PostCardView(post: post, ...)
    }
}

VStack(alignment: .leading, spacing: 8) {  // 8pt between elements in full view
    Text(title)
    Text(summary)
    Image(...)
        .padding(.top, 8)
        .padding(.bottom, 8)
    Text(body)
        .padding(.bottom, 8)
    VStack(spacing: 4) { metadata }  // Tighter spacing for metadata
}
```

## AttributedString Processing

```swift
func processBodyText(_ text: String) -> AttributedString {
    // Remove image markdown: ![alt](url)
    let pattern = "!\\[.*?\\]\\(.*?\\)"
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(text.startIndex..., in: text)
    let cleaned = regex?.stringByReplacingMatches(in: text, options: [],
                                                   range: range, withTemplate: "") ?? text

    var result = AttributedString()
    let lines = cleaned.components(separatedBy: .newlines)

    for (_, line) in lines.enumerated() {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        if trimmedLine.isEmpty {
            // Empty line - add paragraph break only if we have content
            if !result.characters.isEmpty {
                result.append(AttributedString("\n\n"))
            }
        } else if trimmedLine.hasPrefix("## ") {
            // H2 heading - bold and slightly larger
            if !result.characters.isEmpty {
                result.append(AttributedString("\n"))
            }
            var heading = AttributedString(trimmedLine.dropFirst(3))
            heading.font = .system(size: 18, weight: .bold)
            result.append(heading)
            result.append(AttributedString("\n"))
        } else if trimmedLine.hasPrefix("- ") {
            // Bullet point - add bullet and indent
            if !result.characters.isEmpty && !result.characters.last!.isNewline {
                result.append(AttributedString("\n"))
            }
            let bulletText = trimmedLine.dropFirst(2)
            var bullet = AttributedString("• ")
            bullet.font = .body
            result.append(bullet)
            var item = AttributedString(bulletText)
            item.font = .body
            result.append(item)
            result.append(AttributedString("\n"))
        } else {
            // Regular paragraph text
            if !result.characters.isEmpty && !result.characters.last!.isNewline {
                result.append(AttributedString(" "))
            }
            var paragraph = AttributedString(trimmedLine)
            paragraph.font = .body
            result.append(paragraph)
        }
    }

    return result
}
```

**Key iOS-specific decisions**:

**NSRegularExpression for markdown removal**: Use standard regex with escape sequences (`\\[`, `\\]`, `\\(`, `\\)`) to match markdown image syntax.

**AttributedString API**:
- Use `AttributedString()` for building formatted text
- Use `.font` property on AttributedString to set fonts
- Use `.characters` property to check emptiness and access last character
- Use `.append()` to concatenate attributed strings

**String processing**:
- Use `.components(separatedBy: .newlines)` to split by newlines
- Use `.trimmingCharacters(in: .whitespaces)` for whitespace removal
- Use `.hasPrefix()` for markdown detection
- Use `.dropFirst(n)` to remove prefix characters

**Font specification**:
- Use `.system(size:weight:)` for custom font sizes
- Use `.body` for default body text font
- Weight options: `.bold` for headings and titles
