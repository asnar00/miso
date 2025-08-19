# markdown rendering
*GitHub-flavored markdown, sanitized*

Render snippet markdown using GitHub-flavored Markdown.

Supported

- Headings, paragraphs, emphasis, strong, inline code
- Lists, blockquotes, code blocks with fenced syntax highlighting
- Tables, autolinks, task list checkboxes (read-only)

Rules

- Sanitize output: strip or escape raw HTML; no script execution
- Links follow Link Behavior; code blocks show a copy button
- Preserve hard line breaks present in the source

Performance

- Pre-render and memoize by file digest; re-render only on content change


