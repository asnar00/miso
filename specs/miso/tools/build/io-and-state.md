# IO and state
*inputs, outputs, and side-effects*

Contracts:

- Inputs: described in a child snippet titled `Inputs` using plain language (bullet list of fields, types in words, and constraints). `build` synthesizes a machine-readable schema into the generated `manifest.json` and validates at runtime.
- Outputs: described in a child snippet titled `Outputs` using plain language. `build` synthesizes a schema for manifests and validators.
- Side-effects: listed in a child snippet titled `Effects` (e.g., filesystem, network, env). The generator records these in the manifest and adds guardrails (timeouts, path allowlists).

Conventions:

- CLI: generated tools accept `--input` (path to JSON), `--output` (path), and `--dry-run`.
- Library: `execute(context)` receives `inputs` and `options` and returns `{ result, logs }`.
- Stdio: by default, logs go to stderr; result goes to stdout (CLI) or return value (library).

Determinism:

- Tools should be deterministic given the same `inputs` and external state. Non-deterministic operations should be called out in the `Effects` snippet (e.g., time, randomness).


