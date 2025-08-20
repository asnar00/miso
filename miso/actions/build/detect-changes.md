# detect-changes
*identify which snippets and tools need rebuilding*

Compare file modification times between:
- Tool specification files (`.md` snippets) 
- Implementation code in metafolders (`~/imp/platform/`)
- Platform knowledge that might affect the build

If any specification is newer than its corresponding implementation, mark for rebuilding.

Also check dependencies - if a snippet references other snippets via soft-links, and those dependencies changed, mark the dependent tool for rebuilding.

For the first build of any tool, always consider it "changed".