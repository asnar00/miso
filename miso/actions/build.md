# build
*convert specifications to running code*

The `build` action, invoked on a specific snippet defining a tool (i.e. a snippet within `miso/tools/`), ensures that the code implementing that snippet is correct and up-to-date with any recent changes.

- detect which files have changed
- identify which tool needs building
- `assemble context`
- assemble platform context
- resolve any ambiguities with the user
- make a plan for changing the code
- follow the plan in order
- write a report of the changes made
- run the code and iteratively refine with the user
- once the user is happy, update the specification and platform knowledge
- make implementation notes for future agents/users