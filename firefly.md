# firefly
*social media based on semantic search*

`firefly` is a database of short markdown files called "snippets". A snippet has a title, a single-line summary, optionally a single image, and up to 300 words.

Registered users create snippets, which are chunked and converted to embedding vectors, then stored in a vector database.

Users can run queries - natural-language searches or questions - and receive summary answers, with citations to relevant snippets.