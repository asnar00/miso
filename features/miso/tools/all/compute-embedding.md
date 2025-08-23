# compute-embedding
*computes embedding vector for a snippet*

`compute-embedding` reads a snippet and creates an *embedding vector* file that gets stored in the metafolder.

The embedding vector file contains a list of float-vectors, stored as JSON, one for each line in the snippet. We'll use SBERT as the way of computing embedding vectors.

Whenever we run the tool, it checks to see which snippets have changed since the last time it was run; and recomputes embeddings for those snippets.
