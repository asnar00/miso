# Search Cache - Pseudocode

## Database Schema

```sql
CREATE TABLE IF NOT EXISTS search_cache (
    prompt_hash TEXT PRIMARY KEY,
    model_name TEXT NOT NULL,
    llm_results TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_search_cache_model ON search_cache(model_name);
```

## Server: Cache Lookup Function

```
function get_cached_llm_results(prompt: string, model_name: string) -> optional<array>:
    // Compute hash of prompt
    prompt_hash = sha256(prompt)

    // Query database
    result = database.query("""
        SELECT llm_results FROM search_cache
        WHERE prompt_hash = ? AND model_name = ?
    """, [prompt_hash, model_name])

    if result.empty:
        return null

    // Parse JSON results
    llm_results = json.parse(result[0].llm_results)
    log_info(f"[CACHE] Cache HIT for hash {prompt_hash[:8]}...")
    return llm_results
```

## Server: Cache Store Function

```
function store_llm_results(prompt: string, model_name: string, llm_results: array):
    // Compute hash of prompt
    prompt_hash = sha256(prompt)

    // Serialize results
    results_json = json.stringify(llm_results)

    // Insert into database (ignore if already exists)
    database.execute("""
        INSERT INTO search_cache (prompt_hash, model_name, llm_results)
        VALUES (?, ?, ?)
        ON CONFLICT (prompt_hash) DO NOTHING
    """, [prompt_hash, model_name, results_json])

    log_info(f"[CACHE] Cache MISS - stored results for hash {prompt_hash[:8]}...")
```

## Server: Integration into Search

Modify `llm_rerank_posts` function:

```
function llm_rerank_posts(query_post, candidate_posts):
    model_name = "claude-3-5-haiku-20241022"

    // Build prompt
    prompt = build_reranking_prompt(query_post, candidate_posts)

    // Try cache first
    cached_results = get_cached_llm_results(prompt, model_name)
    if cached_results != null:
        return cached_results

    // Cache miss - call Claude API
    api_key = get_anthropic_api_key()
    client = Anthropic(api_key)

    start_time = current_time()
    response = client.messages.create(
        model=model_name,
        max_tokens=2000,
        temperature=0.0,
        messages=[{"role": "user", "content": prompt}]
    )
    duration = current_time() - start_time

    log_info(f"[LLM] API call completed in {duration:.2f} seconds")

    // Parse response
    llm_results = parse_llm_response(response)

    // Store in cache
    store_llm_results(prompt, model_name, llm_results)

    return llm_results
```

## Server: Cache Management

```
function clear_model_cache(model_name: string):
    // Delete all cached entries for a specific model
    database.execute("""
        DELETE FROM search_cache WHERE model_name = ?
    """, [model_name])

    log_info(f"[CACHE] Cleared all entries for model {model_name}")
```

## Patching Instructions

**Target**: `apps/firefly/product/server/imp/py/`

1. **Database Schema** (`db.py`):
   - Add `create_search_cache_table()` function
   - Call it during database initialization

2. **Cache Functions** (`app.py`):
   - Import `hashlib` for SHA256 hashing
   - Add `get_cached_llm_results(prompt, model_name)` function
   - Add `store_llm_results(prompt, model_name, llm_results)` function
   - Modify `llm_rerank_posts()` to check cache before calling Claude API

3. **Model Name**:
   - Define model name constant at top of file: `LLM_MODEL = "claude-3-5-haiku-20241022"`
   - Use this constant in both cache functions and API call
