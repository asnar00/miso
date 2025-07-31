# discovery
*identifies tools that need implementation*

The `discovery` sub-feature examines parsed specifications to identify which ones represent tools that require code generation.

It filters the specification tree to find files under `spec/miso/tools/` (excluding the `tools.md` file itself), extracting the tool name from each path. For each discovered tool, it determines whether implementation is needed by checking:

- Does `run/[tool]/pseudocode.md` exist and match the current spec?
- Does `run/[tool]/[language]/` contain current implementations?
- Have specification files been modified more recently than generated code?
- Have pseudocode files been modified more recently than implementation code?

The discovery process must ensure that implementations are regenerated whenever either the original specification OR the generated pseudocode changes, maintaining a complete dependency chain from spec → pseudocode → implementation.

Discovery creates the work queue for miso's generation pipeline, ensuring only outdated or missing implementations are rebuilt. This incremental approach keeps miso efficient, avoiding unnecessary regeneration of up-to-date tools while ensuring all specifications are properly implemented.

Any bugs fixed in the process should also be reflected back into a `bugfixes/` sub-feature so that insights are preserved for the future.