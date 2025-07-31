# refinement
*collaboratively improves vague or complex specifications*

The `refinement` sub-feature handles cases where tool specifications are too vague, overly complex, or ambiguous to implement directly.

When miso encounters a specification that lacks clear implementation details, it engages the user in collaborative refinement. This process involves:

- **Identifying ambiguity** in specifications that use unclear language or missing details
- **Prompting for clarification** with specific questions about intended behavior
- **Suggesting decomposition** when specifications try to do too much in a single tool
- **Creating child snippets** that break complex functionality into focused sub-features

The refinement process follows the core miso principle: instead of editing the original specification, it creates new child specification files that add the necessary detail. This preserves the high-level intent while providing the specificity needed for implementation.

Through iterative dialogue, refinement helps users evolve their understanding of what they want to build, resulting in clearer specifications and better implementations.