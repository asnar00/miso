# Embedding Pseudocode

## Functions

### chunk_text(text)
**Purpose**: Split text into searchable fragments

**Algorithm**:
1. Split text on any punctuation: `.`, `,`, `;`, `:`, `!`, `?`
2. For each fragment:
   - Strip leading/trailing whitespace
   - If non-empty, add to results
3. Return list of text fragments

**Example**:
```
Input: "Hello, world! How are you?"
Output: ["Hello", "world", "How are you"]
```

---

### quantize_embedding(embedding_float32)
**Purpose**: Convert float32 embedding to int8 for efficient storage

**Algorithm**:
1. Assume embedding values are in range [-1.0, 1.0]
2. Multiply by 127 to scale to [-127.0, 127.0]
3. Convert to int8 type
4. Return quantized embedding

**Note**: all-mpnet-base-v2 outputs normalized embeddings in approximately [-1, 1] range

---

### dequantize_embedding(embedding_int8)
**Purpose**: Convert int8 embedding back to float32 for computation

**Algorithm**:
1. Convert int8 to float32
2. Divide by 127.0 to scale back to [-1.0, 1.0]
3. Return dequantized embedding

---

### generate_embeddings(post_id, title, summary, body)
**Purpose**: Generate and save embeddings for all fragments of a post

**Algorithm**:
1. Load sentence-transformers model 'all-mpnet-base-v2' (cached after first load)
2. Create fragment list:
   - Add title as fragment 0
   - Add summary as fragment 1
   - Chunk body using chunk_text(), add as fragments 2+
3. Generate embeddings for all fragments in one batch (efficient)
4. Quantize all embeddings to int8
5. Stack into numpy array of shape (num_fragments, 768)
6. Save to `data/embeddings/post_{post_id}.npy`

**Dependencies**: sentence-transformers, numpy, torch

---

### load_embeddings(post_id)
**Purpose**: Load embeddings from disk

**Algorithm**:
1. Construct path: `data/embeddings/post_{post_id}.npy`
2. Check if file exists
3. If exists: load and return numpy array
4. If not exists: return None

---

### delete_embeddings(post_id)
**Purpose**: Remove embedding file when post is deleted

**Algorithm**:
1. Construct path: `data/embeddings/post_{post_id}.npy`
2. If file exists: delete it
3. Return success/failure

---

## Integration Points

### When to Generate Embeddings

**On post creation** (`create_post` in db.py):
- After post is saved to database
- Call `generate_embeddings(post_id, title, summary, body)`

**On post update** (`update_post` in db.py):
- After post is updated in database
- Call `generate_embeddings(post_id, title, summary, body)` to regenerate

**On post deletion** (`delete_post` in db.py):
- Call `delete_embeddings(post_id)` before or after deleting from database

### Data Directory

- Embeddings stored in `data/embeddings/` directory
- Create directory on server startup if it doesn't exist
- Directory must exist on remote server at: `~/firefly-server/data/embeddings/`

## Model Details

**Model**: sentence-transformers/all-mpnet-base-v2
- Embedding dimension: 768
- Output type: float32 numpy array
- Pre-trained on large corpus for semantic similarity
- Good balance of quality and speed

**PyTorch Backend**:
- Use MPS (Metal Performance Shaders) on M2 for GPU acceleration
- Model initialization: `model = SentenceTransformer('all-mpnet-base-v2', device='mps')`
- Encoding: `embeddings = model.encode(texts, convert_to_numpy=True)`
