# assemble context
*gather all relevant specification information*

When building a tool, gather context in this systematic order:

- **parent snippets**: read the parent feature specifications (e.g. for `tools/hello`, read `tools`)
- **snippet itself**: read the target snippet being built (e.g. `tools/hello`)  
- **all child snippets**: read any subspecifications within the target (e.g. anything in `tools/hello/`)
- **all concerns/ snippets**: read every snippet under `concerns/` to understand cross-cutting requirements (storage, guidelines, visual-style, etc.)

This ensures no cross-cutting concerns are missed during implementation planning.