# context assembly
*collecting spec files for code generation*

For a tool with id `A/B/C` (spec at `specs/A/B/C.md`), `build` assembles the context that a code-generating agent receives as follows:

Included files

- Ancestors: `specs/A.md`, `specs/A/B.md`
- Self: `specs/A/B/C.md`
- Descendants: every `*.md` under `specs/A/B/C/` recursively

Ordering (deterministic)

1. Ancestors in top-down order: `A.md` → `A/B.md` → `A/B/C.md`
2. Then descendants in lexicographic path order
3. If authors need an explicit sequence among siblings, they may prefix filenames with `01-`, `02-`, ...; the numeric prefix affects order but is ignored when rendering titles

Exclusions

- Non-markdown files are ignored
- Hidden files and directories (starting with `.`) are ignored
- If an ancestor file is missing, `build` continues and notes the omission in the report

Packaging for the agent

- `context_manifest.json`: ordered list of relative paths included in the context
- `context_bundle.txt`: concatenation of the files in order, each separated by a header line:
  - `--- BEGIN specs/<path>.md ---` before content
  - `--- END specs/<path>.md ---` after content

Rationale

- Ancestors provide intent and constraints; descendants provide detail and sub-steps
- Deterministic ordering ensures stable prompts and reproducible generation


