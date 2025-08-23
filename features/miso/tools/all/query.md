# query
*answer any question based on a specification*

The `query` tool answers a question by finding relevant snippets, assembling them into a context, and using an agent (called via an API) to answer the question, using only the assembled snippets.

- use the `search` tool to get a list of snippets
- combine the snippets' text into a single context
- create a prompt with the context, instructions for the agent (something like "you are a question-answering agent") and the query itself
- send the prompt to our agent of choice (Claude for now) via an API
- print the answer

The agent should answer directly and concisely, avoiding phrases like "Based on the provided documentation" since this is implicit. When citing sources, it should reference the .md file path directly (e.g. "miso/tools.md states..."). If the relevant snippets don't actually answer the question, it should say "The documentation doesn't contain enough information to answer this question".