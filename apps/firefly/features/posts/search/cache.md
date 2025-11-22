# Search Cache

*Database caching of LLM re-ranking results to avoid redundant API calls*

The LLM post-processing step takes ~5 seconds per search due to Claude API latency. To improve performance for repeated searches, we cache the LLM scoring results in the database.

**How it works**:
- Cache key is SHA256 hash of the prompt text
- Model name stored separately for easy cache invalidation when upgrading models
- Cache persists indefinitely (no TTL) - automatically invalidates when:
  - Post content changes (different prompt hash)
  - Prompt template changes (different prompt hash)
  - Model is upgraded (lookup uses model_name)

**Performance**:
- Cache hit: ~10ms database lookup (vs 5000ms Claude API call)
- Cache miss: Only adds ~10ms overhead (hash computation + DB insert)
- First search for any query: 5+ seconds (calls Claude)
- Subsequent identical searches: < 100ms (cached)

**Cache invalidation**:
- Automatic via hash mismatch (when posts or prompt change)
- Manual: Delete all entries for old model when upgrading

**Database schema**:
```sql
CREATE TABLE search_cache (
    prompt_hash TEXT PRIMARY KEY,
    model_name TEXT,
    llm_results TEXT,  -- JSON array of {id, score}
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_search_cache_model ON search_cache(model_name);
```

**Usage**:
- Transparent to users - search just gets faster on repeated queries
- No cache management needed in normal operation
- When upgrading Claude model, run: `DELETE FROM search_cache WHERE model_name = 'old-model-name'`
