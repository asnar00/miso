# search
*find relevant specification snippets*

The `search` tool takes a spec (a snippet path eg. `A/B/C`) and a question, and finds the most relevant snippets within the tree.

Whenever a snippet changes, we compute its embedding vector for each snippet (store in metafolder).

To find relevant snippets, we convert the query into an embedding vector, and then perform a breadth-first search through the snippet tree.

At each level, we compute a cosine similarity between the query vector and each snippet's vector; and follow high-similarity branches.

The result is a list of snippet paths that may contain relevant information.