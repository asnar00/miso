# execution model
*how specs become runnable code*

`build` reads a tool's spec snippet, resolves its child snippets, and generates runnable code plus a `pseudocode.md` summary and a `manifest.json`.

Model:

- Source of truth: the spec snippet markdown. `pseudocode.md` is generated from it (not hand-authored).
- Resolution: children of the tool snippet form ordered steps. If no ordering is stated, build uses file name order.
- Generation: selects a template for the requested `--impl` and fills it with data extracted from the spec (title, summary, steps, IO, notes).
- Outputs:
  - Code under `code/<spec_path>/<impl>/`
  - `code/.../pseudocode.md` (generated)
  - `code/.../manifest.json` with entrypoints, IO schema, template versions, and build provenance
- Entrypoints: generated code exposes a CLI `run` subcommand and a library function `execute(context)`.
- Orchestration: agents or humans call the generated CLI or library. `build` does not execute the tool; it only produces it.

Reasonable defaults:

- If no child snippets exist, generate a single-step tool that echoes the summary as a placeholder.
- If ordering matters, authors may prefix child filenames with `01-`, `02-`, ... to force order without changing titles.
- Timestamps and non-deterministic content are avoided; `build` stamps only the spec commit SHA and template version in the manifest.


