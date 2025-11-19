# Database Pool Pseudocode
*Platform-agnostic implementation logic for thread-safe database connection pooling*

## Configuration

```
MIN_CONNECTIONS = 1
MAX_CONNECTIONS = 10
CONNECTION_TIMEOUT = 5 seconds
POSTGRESQL_START_DELAY = 2 seconds
POSTGRESQL_BIN = "/opt/homebrew/opt/postgresql@16/bin/pg_ctl"
POSTGRESQL_DATA = "/opt/homebrew/var/postgresql@16"
```

## Database Class

```
class Database:
    connection_pool = None
    pool_lock = ThreadingLock()
    db_config = {
        host: "localhost",
        port: 5432,
        database: "firefly",
        user: "firefly_user",
        password: "firefly_pass"
    }
```

## PostgreSQL Management

```
function check_postgresql_running() -> boolean:
    result = execute_command([
        POSTGRESQL_BIN, "status",
        "-D", POSTGRESQL_DATA
    ], timeout=5)
    return result.returncode == 0

function restart_postgresql() -> boolean:
    log("[DB] PostgreSQL not responding, attempting to restart...")

    result = execute_command([
        POSTGRESQL_BIN, "start",
        "-D", POSTGRESQL_DATA,
        "-l", "/opt/homebrew/var/log/postgresql@16.log"
    ], timeout=10)

    if result.returncode == 0:
        log("[DB] PostgreSQL started successfully")
        wait(POSTGRESQL_START_DELAY)
        return true
    else:
        log("[DB] Failed to start PostgreSQL: " + result.stderr)
        return false
```

## Thread-Safe Pool Initialization

```
function initialize_pool(minconn=1, maxconn=10, retry_with_restart=true):
    # CRITICAL: Lock prevents concurrent initialization
    acquire_lock(pool_lock):

        # Double-check: another thread may have initialized while waiting
        if connection_pool is not null:
            log("[DB] Pool already initialized, skipping")
            return

        try:
            # Create connection pool
            connection_pool = create_connection_pool(
                minconn, maxconn, db_config
            )
            log("[DB] Database connection pool initialized: " +
                db_config.host + ":" + db_config.port + "/" + db_config.database)

        except ConnectionRefusedError as e:
            log("[DB] Error initializing database pool: " + e)

            # Try to restart PostgreSQL and retry
            if retry_with_restart and "Connection refused" in e.message:
                log("[DB] Attempting to restart PostgreSQL and retry...")

                if restart_postgresql():
                    try:
                        connection_pool = create_connection_pool(
                            minconn, maxconn, db_config
                        )
                        log("[DB] Database connection pool initialized after restart")
                        return
                    except error as e2:
                        log("[DB] Failed to initialize pool after restart: " + e2)

            # Re-raise if we couldn't recover
            throw e
```

## Connection Management

```
function get_connection():
    # Lazy initialization if pool not yet created
    if connection_pool is null:
        initialize_pool()

    try:
        return connection_pool.get_connection()
    except error as e:
        # Pool may be corrupted, try reinitializing
        log("[DB] Error getting connection, reinitializing pool: " + e)
        connection_pool = null
        initialize_pool()
        return connection_pool.get_connection()

function return_connection(conn):
    if connection_pool is not null and conn is not null:
        try:
            connection_pool.put_connection(conn)
        except error as e:
            # Connection is corrupted - close it and reset pool
            log("[DB] Error returning connection to pool: " + e)
            try:
                conn.close()
            catch:
                pass  # Ignore errors closing corrupted connection

            # Reset the pool to recover from corruption
            log("[DB] Resetting connection pool due to corruption")
            connection_pool.close_all()
            connection_pool = null
```

## Startup Health Check

```
function startup_health_check():
    log("=" * 60)
    log("Performing startup health checks...")
    log("=" * 60)

    # Check 1: PostgreSQL is running
    log("[HEALTH] Checking PostgreSQL status...")
    if not check_postgresql_running():
        log("[HEALTH] PostgreSQL is not running, attempting to start...")
        if restart_postgresql():
            log("[HEALTH] PostgreSQL started successfully")
        else:
            log("[HEALTH] CRITICAL: Failed to start PostgreSQL - server cannot start")
            exit(1)
    else:
        log("[HEALTH] PostgreSQL is running")

    # Check 2: Initialize database connection pool
    log("[HEALTH] Initializing database connection pool...")
    try:
        initialize_pool()
        log("[HEALTH] Database connection pool initialized successfully")
    except error as e:
        log("[HEALTH] CRITICAL: Failed to initialize database pool: " + e)
        log("[HEALTH] Server cannot start without database connection")
        exit(1)

    # Check 3: Test database connection
    log("[HEALTH] Testing database connection...")
    try:
        conn = get_connection()
        return_connection(conn)
        log("[HEALTH] Database connection test successful")
    except error as e:
        log("[HEALTH] CRITICAL: Database connection test failed: " + e)
        exit(1)

    log("=" * 60)
    log("[HEALTH] All startup checks passed!")
    log("=" * 60)
```

## Server Startup Integration

```
function main():
    # Register signal handlers
    register_signal_handler(SIGTERM, handle_sigterm)

    # CRITICAL: Run health checks BEFORE starting server
    startup_health_check()

    # Log startup information
    log("Starting Firefly server on http://0.0.0.0:8080")

    # Start Flask server (will use already-initialized pool)
    try:
        flask_app.run(host="0.0.0.0", port=8080, debug=false)
    except error as e:
        log("CRITICAL: Fatal error during server execution: " + e)
        exit(1)
    finally:
        log("Server stopped")
```

## Patching Instructions

### For Python Flask Server

**File**: `apps/firefly/product/server/imp/py/db.py`

1. Import `threading` module
2. Add `_pool_lock = threading.Lock()` to Database.__init__()
3. Add `check_postgresql_running()` method using subprocess
4. Wrap `initialize_pool()` body with `with self._pool_lock:`
5. Add double-check for `connection_pool is not None` inside lock
6. Update `restart_postgresql()` to return boolean success status

**File**: `apps/firefly/product/server/imp/py/app.py`

1. Create `startup_health_check()` function before `if __name__ == '__main__':`
2. Call `startup_health_check()` immediately after signal handler registration
3. Ensure health check runs BEFORE `app.run()`

### Testing Verification

**Successful startup should show**:
```
[HEALTH] Checking PostgreSQL status... ✓
[HEALTH] PostgreSQL is running ✓
[HEALTH] Initializing database connection pool... ✓
[HEALTH] Database connection pool initialized successfully ✓
[HEALTH] Testing database connection... ✓
[HEALTH] All startup checks passed! ✓
```

**Failed startup should exit immediately** with clear error message indicating which check failed.

## Critical Details

1. **Thread safety is essential**: Without the lock, concurrent requests during startup can corrupt the pool
2. **Double-check pattern**: Check `connection_pool` again inside lock to avoid re-initialization
3. **Fail-fast on startup**: Better to not start than to start in a broken state
4. **PostgreSQL must be first**: Server requires database to initialize, so check it before anything else
5. **Lock scope**: Keep lock scope as small as possible (just pool creation, not the entire function)
6. **Lazy initialization fallback**: `get_connection()` still has lazy init for backward compatibility
7. **Connection corruption recovery**: If putting connection back fails, reset entire pool
8. **Subprocess timeout**: PostgreSQL status check should timeout after 5 seconds to avoid hanging

## Error Scenarios Handled

1. **PostgreSQL not running**: Automatically starts it, then initializes pool
2. **Concurrent initialization**: Lock prevents race condition
3. **Pool corruption**: Detected and recovered by resetting pool
4. **Connection failure**: Pool re-initialized automatically
5. **Startup failure**: Server exits with clear error instead of running broken
