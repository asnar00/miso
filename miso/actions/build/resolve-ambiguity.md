# resolve-ambiguity
*clarify unclear specifications before implementation*

Use all available approaches to resolve ambiguity:

**Context-aware resolution**: Check surrounding snippets, platform knowledge, and existing implementations for clues about the intended behavior.

**Convention-based defaults**: Apply platform conventions to make reasonable assumptions (e.g., SwiftUI apps should have standard window behavior).

**Interactive clarification**: When context and conventions aren't sufficient, present numbered options to the user for quick selection.

**Specification enhancement**: After resolving ambiguity, update the original snippet to be clearer for future builds.

Document all resolution decisions in the build report for transparency.