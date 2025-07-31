# miso

The `miso` tool's job is to "compile" feature-modular specifications (in the `spec/` folder) into working tools (in the `run/` folder).

When invoked, `miso` ensures that the pseudocode, and the current active implementation code of each tool, correctly implements the most recent version of the spec.

If the tool is vaguely defined or overly complex, `miso` engages in *collaborative refinement* with the user, adding new sub-feature snippets to better define the tool.