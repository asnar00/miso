# parsing
*reads and understands specification files*

The `parsing` sub-feature handles the discovery and interpretation of markdown specification files throughout the `spec/` directory tree.

It recursively scans for `.md` files, extracting the title (first `#` heading) and summary (first emphasized line) from each specification. The parser builds a complete map of the specification tree, converting file paths like `spec/miso/tools/hello.md` into specification names like `miso/tools/hello`.

Each parsed specification includes its title, summary, full content, and file path for later processing. The parser validates markdown structure and handles malformed files gracefully, ensuring the rest of the miso pipeline can operate on clean, well-structured data.

This foundation enables all other miso functionality by providing a unified view of the specification ecosystem.