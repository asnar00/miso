# assemble relevant context
*how to make sure the agent has the right information*

Assemble a single context from multiple .md files in the spec snippet tree.

When building tool `A/B/C.md`, get the following:

- parent snippets `A.md`, `A/B.md`
- the snippet itself `A/B/C.md`
- all child snippets `A/B/C/*.md`

If any of these snippets refer to other cross-cutting concerns using `softlinks`, see if you can find and add context for those as well.