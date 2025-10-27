# implementation
*going from feature change to code change*

When the user makes a change to a feature `A/B.md`, or adds a subfeature, the `implementation` process ensures that code is created according to a set routine:

1. **Pseudocode**: Check if `A/B/imp/pseudocode.md` is up-to-date. If not, update it to reflect feature changes using natural language function definitions and patching instructions.

2. **Platform Code**: Check if platform implementations (`A/B/imp/ios.md`, `/eos.md`, `/py.md`) are up-to-date vs pseudocode. If not, update them with platform-appropriate code syntax.

3. **Product Code**: Check if actual product code is up-to-date vs platform implementations. If not, apply modifications following patching instructions.

4. **Build, Deploy, Test**: Build and deploy to devices/servers, then run tests if available.

5. **Visual Verification** (for UI changes): Take screenshots and verify visible results match the specification. If not, investigate missed files, fix them, and iterate until visual verification passes. Then update implementation documentation to capture all discovered changes for future runs.

The miso skill (`.claude/skills/miso/`) automates this workflow.