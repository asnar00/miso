# miso pseudocode

## parsing phase
- recursively scan all `.md` files in `spec/` directory tree
- for each file, extract:
  - title (first `#` heading)
  - summary (first emphasized line after title)
  - full content
  - file path
- convert file paths to specification names (e.g., `spec/miso/tools/hello.md` → `miso/tools/hello`)
- validate markdown structure and handle malformed files gracefully
- build complete map of specification tree

## context assembly phase
- for each tool `A/B/C` being built, assemble context from:
  - parent context: `spec/A.md`, `spec/A/B.md`
  - feature snippet itself: `spec/A/B/C.md`
  - all child snippets: `spec/A/B/C/D.md`, `spec/A/B/C/D/E.md`, `spec/A/B/C/F.md`, etc.
- merge all relevant information to build complete understanding of tool requirements
- ensure no specification details are missed when generating implementations

## discovery phase
- filter specification tree to find files under `spec/miso/tools/` (excluding `tools.md` itself)
- extract tool name from each path
- for each discovered tool, check if implementation is needed:
  - if `run/[tool]/` directory doesn't exist: NEEDS FULL GENERATION
  - if `run/[tool]/pseudocode.md` doesn't exist: NEEDS PSEUDOCODE GENERATION
  - if `run/[tool]/pseudocode.md` exists but spec is newer: NEEDS PSEUDOCODE UPDATE
  - if no `run/[tool]/[language]/` directories exist: NEEDS CODE GENERATION
  - if pseudocode is newer than code implementations: NEEDS CODE UPDATE
- create work queue of tools needing updates with specific actions required
- maintain complete dependency chain: spec → pseudocode → implementation

## pseudocode generation phase
- for each tool needing pseudocode updates:
  - analyze tool specification content using assembled context
  - extract core behavior and functionality
  - break down into step-by-step instructions
  - write clear, implementable pseudocode in `run/[tool]/pseudocode.md`
  - ensure pseudocode follows project conventions:
    - use bullet points to indicate sequence
    - be both concise and precise
    - describe function of tool clearly

## code generation phase
- for each tool needing implementation updates:
  - read generated pseudocode for the tool
  - choose appropriate language/platform based on requirements
  - generate working code in `run/[tool]/[language]/` directory
  - apply templates for argument parsing, main logic, error handling
  - set proper file permissions and shebang lines
  - extract expected output from specification examples
  - create fully functional implementations or TODO-marked templates for vague specs
  - maintain traceability from specification to executable code

## testing phase
- for each generated or updated tool:
  - execute the tool to verify it runs without errors
  - check actual output against expected behavior from specification examples
  - validate functionality by testing core features described in spec
  - if tool doesn't work as intended:
    - analyze what went wrong (wrong output, missing functionality, errors)
    - update specifications with more precise implementation details
    - regenerate pseudocode and implementations
    - test again until tool matches specification requirements
- persist until success - keep iterating improvements until tools work correctly
- ensure generated tools actually fulfill their intended purpose, not just syntactic correctness

## collaborative refinement phase
- identify specifications that are vague, complex, or ambiguous
- for unclear specifications:
  - prompt user for clarification with specific questions
  - suggest breaking complex tools into focused sub-features
  - create child specification files that add necessary detail
  - preserve high-level intent while providing implementation specificity
- engage in iterative dialogue to evolve user understanding
- follow core miso principle: add child snippets rather than edit original specs

## bugfix handling
- implement special-case handling to prevent self-overwriting issues
- skip regenerating miso tool itself during normal processing to maintain system stability
- preserve working implementations when specifications are updated
- handle bootstrap challenges gracefully in self-hosting system

## error handling and output
- validate markdown format of all specifications
- handle missing or malformed spec files gracefully
- provide clear error messages for implementation failures
- create directory structure as needed
- write generated files with proper permissions
- provide summary of what was created/updated
- log all actions for debugging purposes