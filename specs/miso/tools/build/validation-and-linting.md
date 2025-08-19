# validation and linting
*ensuring snippet quality and safe builds*

Checks performed by `build` before codegen:

- Snippet rules: title present, single-line emphasized summary, length under ~300 words, ≤6 children.
- No frontmatter required: specs are prose-first. If frontmatter exists, it is ignored for behavior and treated as comments.
- Links: child snippet paths exist and are unique.
- IO schemas: synthesized from `Inputs`/`Outputs` child snippets; the synthesized schemas are validated for self-consistency.

On failure:

- Abort with a readable error list and suggested fixes.
- Emit `build_report.json` with all diagnostics.

Command:

    >miso build --lint-only specs/A/B/C.md
    3 checks passed, 0 errors


