# security and sandboxing
*limits, permissions, and safe execution*

Principles:

- Least privilege: generated tools request only capabilities they need, declared in `effects` and reflected in the manifest.
- Safe defaults: network disabled by default; filesystem access restricted to the working directory unless whitelisted.
- Timeouts and quotas: default execution timeout (e.g., 60s) and memory limit; configurable via flags/env.

Mechanisms:

- CLI wrappers: generated CLIs optionally run under a sandbox (e.g., `uv` for Python venvs, `docker`/`podman` when available).
- Policy file: `policy.json` in the implementation folder lists allowed env vars, outbound domains, and writable paths.
- Input/Output validation: enforced at runtime using the declared schemas; unexpected fields rejected.

Operational guidance:

- For untrusted specs, require `--sandbox docker` and drop all privileges.
- Add `--allow-net` or `--allow-path ./data` to opt into capabilities at run-time.


