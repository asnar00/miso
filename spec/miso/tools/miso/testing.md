# testing
*validates that generated tools actually work as specified*

The `testing` sub-feature ensures that miso doesn't just generate code, but verifies that tools actually perform their specified behavior correctly.

After generating or updating any tool, miso should:

- **Execute the tool** to verify it runs without errors
- **Check actual output** against expected behavior from specification examples
- **Validate functionality** by testing core features described in the spec
- **Iterate improvements** when tools don't work as intended
- **Persist until success** - keep refining specifications and implementations until tools work correctly

When testing reveals issues, miso should:
- Analyze what went wrong (wrong output, missing functionality, errors)
- Update specifications with more precise implementation details
- Regenerate pseudocode and implementations
- Test again until the tool matches specification requirements

This testing phase transforms miso from a code generator into a complete development system that ensures generated tools actually fulfill their intended purpose. The goal is working tools, not just syntactically correct code.