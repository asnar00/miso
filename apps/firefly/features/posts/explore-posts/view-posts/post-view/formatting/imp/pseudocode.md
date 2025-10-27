# formatting pseudocode

## Text Sizing Constants

```
TITLE = 24pt bold (same in both compact and expanded states)
SUMMARY = 14pt subheadline italic
BODY = standard system size
HEADING = 18pt bold
METADATA = 12pt caption at 60% opacity
```

## Spacing Constants

```
CARD_SPACING = 8pt        // between cards
ELEMENT_SPACING = 8pt     // within cards
IMAGE_PADDING_VERTICAL = 8pt
BODY_BOTTOM_PADDING = 8pt
```

## Border Constants

```
CARD_CORNER_RADIUS = 12pt
IMAGE_CORNER_RADIUS = 12pt
CARD_SHADOW = 2pt
```

## Color Constants

```
BACKGROUND_COLOR = #40E0D0 (turquoise)
CARD_BACKGROUND = white at 90% opacity
TEXT_COLOR = black
SUMMARY_COLOR = black at 80% opacity
METADATA_COLOR = black at 60% opacity
```

## Markdown Text Processing

```
function processBodyText(text):
  // Remove image markdown
  cleaned = remove_pattern(text, "!\[.*?\]\(.*?\)")

  result = empty AttributedString
  lines = split(cleaned, by: newlines)

  for line in lines:
    trimmed = trim_whitespace(line)

    if trimmed is empty:
      // Paragraph break - only if we have existing content
      if result not empty:
        append(result, "\n\n")

    else if trimmed starts with "## ":
      // H2 heading
      if result not empty:
        append(result, "\n")
      heading = substring(trimmed, from: 3)
      append(result, heading with 18pt bold font)
      append(result, "\n")

    else if trimmed starts with "- ":
      // Bullet point
      if result not empty and last char not newline:
        append(result, "\n")
      bulletText = substring(trimmed, from: 2)
      append(result, "• ")
      append(result, bulletText)
      append(result, "\n")

    else:
      // Regular paragraph
      if result not empty and last char not newline:
        append(result, " ")  // space-join continuation
      append(result, trimmed)

  return result
```

**Key decisions**:
- Only add paragraph breaks (`\n\n`) when there's already content, avoiding leading whitespace
- Space-join consecutive non-empty lines within the same paragraph
- Convert markdown bullets to actual bullet characters (•)
- Bold and enlarge H2 headings
