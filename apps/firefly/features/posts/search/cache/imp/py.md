# Search Cache - Python Implementation

## Database Schema (db.py)

Add method to Database class at line 817:

```python
def create_search_cache_table(self):
    """Create search_cache table for LLM result caching"""
    conn = self.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS search_cache (
                    prompt_hash TEXT PRIMARY KEY,
                    model_name TEXT NOT NULL,
                    llm_results TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cur.execute("""
                CREATE INDEX IF NOT EXISTS idx_search_cache_model
                ON search_cache(model_name)
            """)

            conn.commit()
            print("Search cache table created successfully")
    except Exception as e:
        conn.rollback()
        print(f"Error creating search_cache table: {e}")
    finally:
        self.return_connection(conn)
```

Call during server startup in `app.py` `startup_health_check()` function (after line 1306):

```python
# Check 4: Create search_cache table if needed
logger.info("[HEALTH] Creating search_cache table if needed...")
try:
    db.create_search_cache_table()
    logger.info("[HEALTH] Search cache table ready")
except Exception as e:
    logger.warning(f"[HEALTH] Failed to create search_cache table: {e}")
    logger.warning("[HEALTH] Search caching will be disabled")
```

## Cache Functions (app.py)

Add import at line 18 (after existing imports):

```python
import hashlib
```

Note: `json` is already imported at line 17.

Define model constant at line 36 (after Flask app initialization):

```python
# LLM model for search re-ranking
LLM_MODEL = "claude-3-5-haiku-20241022"
```

Add cache lookup function at line 1141 (before `llm_rerank_posts`):

```python
def get_cached_llm_results(prompt, model_name):
    """Check cache for LLM results"""
    try:
        # Compute prompt hash
        prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

        # Query database
        conn = db.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT llm_results FROM search_cache
            WHERE prompt_hash = %s AND model_name = %s
        """, (prompt_hash, model_name))

        result = cursor.fetchone()
        db.return_connection(conn)

        if result:
            llm_results = json.loads(result[0])
            logger.info(f"[CACHE] ✓ HIT for hash {prompt_hash[:8]}... ({len(llm_results)} results)")
            return llm_results

        logger.info(f"[CACHE] ✗ MISS for hash {prompt_hash[:8]}...")
        return None

    except Exception as e:
        logger.error(f"[CACHE] Error reading cache: {e}")
        return None
```

Add cache store function at line 1170:

```python
def store_llm_results(prompt, model_name, llm_results):
    """Store LLM results in cache"""
    try:
        # Compute prompt hash
        prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

        # Serialize results
        results_json = json.dumps(llm_results)

        # Insert into database
        conn = db.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO search_cache (prompt_hash, model_name, llm_results)
            VALUES (%s, %s, %s)
            ON CONFLICT (prompt_hash) DO NOTHING
        """, (prompt_hash, model_name, results_json))

        conn.commit()
        db.return_connection(conn)

        logger.info(f"[CACHE] Stored results for hash {prompt_hash[:8]}...")

    except Exception as e:
        logger.error(f"[CACHE] Error storing cache: {e}")
```

## Modify llm_rerank_posts Function

Update the function at line 1196 to use caching. Add cache check after building prompt (line 1212-1215) and cache storage after parsing results (line 1270):

```python
def llm_rerank_posts(query_post, candidate_posts):
    """Use Claude Haiku to re-rank search results"""
    try:
        # Get API key from config
        api_key = config.get_anthropic_api_key()
        if not api_key:
            raise Exception("ANTHROPIC_API_KEY not found in environment")

        # Initialize Anthropic client
        client = Anthropic(api_key=api_key)

        # Build prompt
        prompt = build_reranking_prompt(query_post, candidate_posts)

        logger.info(f"[LLM] Prompt being sent to Claude:\n{prompt}")

        # CHECK CACHE FIRST
        cached_results = get_cached_llm_results(prompt, LLM_MODEL)
        if cached_results is not None:
            return cached_results

        # Call Claude Haiku API
        import time
        logger.info("[LLM] Calling Claude Haiku for re-ranking...")
        start_time = time.time()
        response = client.messages.create(
            model=LLM_MODEL,  # Changed from hardcoded string to constant
            max_tokens=2000,
            temperature=0.0,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )
        end_time = time.time()
        api_duration = end_time - start_time
        logger.info(f"[LLM] API call completed in {api_duration:.2f} seconds")

        # Parse JSON response
        response_text = response.content[0].text
        logger.info(f"[LLM] Raw response: {response_text}")

        # Extract JSON from response (handle potential markdown code blocks and extra text)
        json_text = response_text.strip()

        if "```json" in json_text:
            json_start = json_text.find("```json") + 7
            json_end = json_text.find("```", json_start)
            json_text = json_text[json_start:json_end].strip()
        elif "```" in json_text:
            json_start = json_text.find("```") + 3
            json_end = json_text.find("```", json_start)
            json_text = json_text[json_start:json_end].strip()
        else:
            # Find the JSON array start (may have explanatory text before it)
            array_start = json_text.find('[')
            if array_start >= 0:
                json_text = json_text[array_start:]
                # Find matching closing bracket
                bracket_count = 0
                for i, char in enumerate(json_text):
                    if char == '[':
                        bracket_count += 1
                    elif char == ']':
                        bracket_count -= 1
                        if bracket_count == 0:
                            json_text = json_text[:i+1]
                            break

        logger.info(f"[LLM] Extracted JSON text: {json_text[:200]}...")
        scores = json.loads(json_text)
        logger.info(f"[LLM] Successfully parsed {len(scores)} scores")

        # STORE IN CACHE
        store_llm_results(prompt, LLM_MODEL, scores)

        return scores

    except Exception as e:
        logger.error(f"[LLM] Re-ranking failed: {e}", exc_info=True)
        raise
```

## Patching Instructions

**Target files**:
1. `apps/firefly/product/server/imp/py/db.py` - Add table creation method
2. `apps/firefly/product/server/imp/py/app.py` - Add caching logic and startup initialization

**Steps**:

1. **In `db.py`**:
   - Add `create_search_cache_table()` method to Database class at line 817 (after `set_post_parent()` method)

2. **In `app.py`**:
   - Line 18: Add `import hashlib` after existing imports
   - Line 36: Add `LLM_MODEL = "claude-3-5-haiku-20241022"` constant after Flask app initialization
   - Line 1141: Add `get_cached_llm_results()` function before `llm_rerank_posts()`
   - Line 1170: Add `store_llm_results()` function
   - Line 1196: Modify `llm_rerank_posts()`:
     - Line 1212-1215: Add cache check after building prompt
     - Line 1222: Change hardcoded model string to `LLM_MODEL` constant
     - Line 1270: Add cache storage call after parsing results
   - Line 1308: Add table creation check in `startup_health_check()` function

**Deployment**:
1. Copy updated files to remote server
2. Restart server
3. Verify in logs: "Search cache table created successfully"
4. Test with repeated search queries to verify cache hits

**Verification**:
- First search query: Logs show `[CACHE] ✗ MISS` and `[LLM] API call completed in ~5 seconds`
- Second identical search: Logs show `[CACHE] ✓ HIT` with no API call
- Total search time drops from ~5s to <0.1s on cache hits
