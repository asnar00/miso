# versioning and reproducibility
*traceable, repeatable builds*

Provenance recorded in `manifest.json`:

- `spec_path`, `spec_title`, `spec_summary`
- `spec_commit_sha` (if git available) and dirty flag
- `build_timestamp` (UTC), `build_user`
- `build_tool_version` and `template_catalog_version`
- `impl_key`, `template_name`, `template_commit_sha`
- `inputs_schema_digest`, `outputs_schema_digest`

Policies:

- Templates are versioned; `build` pins template version in the manifest. Rebuilding with the same versions yields identical outputs.
- A `lockfile` (`code/.../build.lock.json`) captures template sources and dependency pins for language-specific package managers when applicable.
- Semver recommended for tools; breaking IO changes bump major.

Commands:

    >miso build specs/A/B/C.md --impl py --template-version 1.2.0
    Pinned template 1.2.0 → manifest.template_catalog_version=1.2.0


