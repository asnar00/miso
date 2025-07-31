# bugfixes
*preventing miso from overwriting its own working implementation*

The `bugfixes` sub-feature addresses critical issues discovered during miso development, particularly the self-destruction problem where miso would overwrite its own working code.

## the self-overwriting issue

When miso processes tool specifications, it compares file modification times to determine what needs regeneration. However, this created a bootstrap problem: after creating sub-feature snippets for miso itself, the main `spec/miso/tools/miso.md` appeared newer than the working implementation, causing miso to replace its own functional code with a generic "not yet implemented" stub.

## solution approach

The fix involves special-case handling in the tool generation pipeline:
- Skip regenerating the miso tool itself during normal processing
- Preserve the working miso implementation to maintain system stability
- Allow manual updates to miso code when intentionally developing new features

This solution maintains the self-hosting nature of miso while preventing accidental self-destruction. It demonstrates how specification systems must handle their own bootstrap challenges gracefully.