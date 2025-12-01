# embedding
*generate and store vector embeddings for post fragments*

Converts post text into semantic vector embeddings for similarity search. Each post is split into fragments (title, summary, body chunks), embedded using all-mpnet-base-v2, quantized to int8, and stored as numpy arrays.

**Chunking strategy**:
- Title: single fragment
- Summary: single fragment
- Body: split on any punctuation (.,;:!?) into separate fragments
- Strip whitespace, skip empty fragments
- Each fragment embedded independently

**Embedding generation**:
- Model: sentence-transformers/all-mpnet-base-v2
- Output: 768-dimensional float32 vectors
- Quantize to int8 for storage: scale [-1, 1] → [-127, 127]
- Dequantize for search: scale [-127, 127] → [-1.0, 1.0]

**Storage format**:
- Location: `data/embeddings/post_{id}.npy`
- Format: numpy array of int8, shape (num_fragments, 768)
- Row 0: title embedding
- Row 1: summary embedding
- Row 2+: body fragment embeddings in order

**Operations**:
- `generate_embeddings(post_id, title, summary, body)` - create and save embeddings for a post
- `load_embeddings(post_id)` - load embeddings from disk
- `delete_embeddings(post_id)` - remove embedding file
- `chunk_text(text)` - split text into fragments
