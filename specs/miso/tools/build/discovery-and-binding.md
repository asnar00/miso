# discovery and binding
*how specs find and choose implementations*

Binding rules:

- Location: a tool spec at `specs/A/B/C.md` binds to implementations in `code/A/B/C/<impl>/`.
- Manifest: each implementation folder contains an optional `manifest.json` describing entrypoints, dependencies, and minimum runtime version. If missing, `build` writes it.
- Selection: the `--impl` flag selects a single implementation key (e.g., `py`, `sh`). If the folder exists, `build` updates it in-place; otherwise, it scaffolds from a template.
- Multiple implementations: allowed side-by-side. A child snippet titled `Implementation Preferences` can suggest a default implementation (e.g., `py`) used when `--impl` is omitted.
- Templates: resolved by name `<impl>` from the standard template catalog packaged with `build` (versioned). Users can override with `--template path`.
- Cross-references: parent tools can depend on child tools by path; the generator will emit imports or subprocess calls accordingly.

Identifiers:

- Implementation keys are short lowercase tokens: `py`, `sh`, `ts`, `go`.
- A tool's canonical id is its spec path without extension: `A/B/C`.


