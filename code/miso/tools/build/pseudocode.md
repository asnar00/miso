# build
*compile a tool spec into executable code*

Goal: Given a tool spec markdown file and a requested implementation key, generate runnable code under `code/<tool_id>/<impl>/`, plus a manifest and pseudocode describing the generated tool.

Inputs

- CLI args:
  - `spec`: path to a tool spec markdown file (e.g., `specs/tools/hello.md`)
  - `--impl`: implementation key (supported: `py`, `sh`)

Definitions

- `tool_id`: the spec path relative to `specs/` without the `.md` extension. Example: `specs/tools/hello.md` → `tools/hello`.
- `title`: first line that starts with `# `; stripped of the leading `#` and spaces.
- `summary`: the first emphasized single-line summary after the title, where the entire trimmed line is wrapped in `*...*`.
- `suggested_output_line`: a best-effort output string derived from the spec. Heuristics:
  1. If any line contains the substring `hello world!` (case-insensitive search but preserve original casing), use `"hello world!"` from that line.
  2. Otherwise, if a line equals `hello` or starts with `>hello`, use the next non-empty line (trimmed and with any leading `>` removed).
  3. Otherwise, leave unset.
- `message`: choose in order: `suggested_output_line`, else `summary`, else `title`.

Procedure

1) Validate inputs
   - If `spec` does not exist, exit with an error.
   - If `--impl` is not one of `py`, `sh`, exit with an error listing supported keys.

2) Read and summarize the spec
   - Read the markdown file at `spec`.
   - Extract `title` and `summary` from the top of the document (inspect up to the first ~5 lines after the title for the summary).
   - Compute `tool_id` from the path.
   - Compute `suggested_output_line` using the heuristics above.
   - Compute `message` as defined.

3) Generate implementation (branch on `--impl`)
   - For `py`:
     - Ensure directory `code/<tool_id>/py` exists.
     - Write `code/<tool_id>/py/main.py` that:
       - Exposes `execute()` which prints `message` followed by a newline and returns exit code 0.
       - Exposes `main()` that parses default CLI flags and exits with the result of `execute()`.
     - Make no network or filesystem changes beyond writing generated files.

   - For `sh`:
     - Ensure directory `code/<tool_id>/sh` exists.
     - Write POSIX shell script `code/<tool_id>/sh/run` that:
       - Uses `#!/usr/bin/env sh` and `set -eu`.
       - Prints `message` followed by a newline via `echo`, safely quoted for POSIX shells.
       - Is marked executable.

4) Generate artifact metadata alongside the implementation
   - Write `code/<tool_id>/<impl>/pseudocode.md` describing the generated tool (summary, behavior: print `message`).
   - Write `code/<tool_id>/<impl>/manifest.json` with fields:
     - `spec_path`, `spec_title`, `spec_summary`
     - `spec_commit_sha` if available from `git rev-parse HEAD`, else null
     - `build_timestamp` as UTC ISO-8601
     - `build_tool_version` set to the current build tool version (e.g., `0.1.0`)
     - `template_catalog_version` set to `"builtin-0.1"`
     - `impl_key` set to the provided `--impl`
     - `template_name` set to `"builtin/echo"`
     - `entrypoints` object:
       - For `py`: `{"cli": "main.py", "library": "execute"}`
       - For `sh`: `{"cli": "run", "library": null}`

5) Reporting
   - Print a single line: `Wrote code/<tool_id>/<impl>`

Notes

- Determinism: For the same spec contents and build tool/template versions, the outputs are stable except for `build_timestamp` and `spec_commit_sha`.
- Security: This build process performs only local file writes under `code/` and does not execute external code from the spec.


