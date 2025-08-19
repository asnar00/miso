# build
*compile a tool spec into executable code*

`build` takes a tool's specification snippet and produces code in a requested implementation (for example `py`, `sh`, `ts`). It resolves the snippet tree, selects or scaffolds an implementation, and writes files to the `code/` tree with an execution manifest.

Scope:

- Input: a snippet path (e.g., `miso/tools/build`) or file (`specs/.../X.md`), an implementation key (e.g., `py`), and optional flags.
- Output: generated source files under `code/.../X/<impl>/`, a `manifest.json` describing the build, and logs.
- Guarantees: repeatable builds from the same inputs and template versions.

Usage:

    >miso build specs/miso/tools/build.md --impl py
    Wrote code/miso/tools/build/py (7 files)

Child snippets detail the execution model, runtime responsibilities, IO contracts, validation, versioning, and security.


