# Database Pool Python Implementation
*Flask server with thread-safe PostgreSQL connection pooling*

## Files Modified

- `apps/firefly/product/server/imp/py/db.py` - Database connection pool class
- `apps/firefly/product/server/imp/py/app.py` - Flask server startup with health checks

## db.py - Database Class

**Import additions:**
```python
import threading
```

**Database.__init__() - Add thread lock:**
```python
def __init__(self, db_config: Optional[Dict[str, str]] = None):
    """Initialize database connection pool."""
    if db_config is None:
        db_config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': os.getenv('DB_PORT', '5432'),
            'database': os.getenv('DB_NAME', 'firefly'),
            'user': os.getenv('DB_USER', 'firefly_user'),
            'password': os.getenv('DB_PASSWORD', 'firefly_pass')
        }

    self.db_config = db_config
    self.connection_pool = None
    self._pool_lock = threading.Lock()  # Thread safety for pool initialization
```

**check_postgresql_running() - New method:**
```python
def check_postgresql_running(self):
    """Check if PostgreSQL is running"""
    try:
        result = subprocess.run([
            '/opt/homebrew/opt/postgresql@16/bin/pg_ctl',
            '-D', '/opt/homebrew/var/postgresql@16',
            'status'
        ], capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except Exception as e:
        print(f"[DB] Error checking PostgreSQL status: {e}")
        return False
```

**initialize_pool() - Thread-safe version:**
```python
def initialize_pool(self, minconn=1, maxconn=10, retry_with_restart=True):
    """Initialize the connection pool with thread safety"""
    with self._pool_lock:
        # Check again inside the lock to avoid double initialization
        if self.connection_pool is not None:
            print("[DB] Pool already initialized, skipping")
            return

        try:
            self.connection_pool = psycopg2.pool.SimpleConnectionPool(
                minconn, maxconn, **self.db_config
            )
            print(f"Database connection pool initialized: {self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}")
        except Exception as e:
            print(f"Error initializing database pool: {e}")

            # Try to restart PostgreSQL and retry
            if retry_with_restart and "Connection refused" in str(e):
                print("[DB] Attempting to restart PostgreSQL and retry...")
                if self.restart_postgresql():
                    try:
                        self.connection_pool = psycopg2.pool.SimpleConnectionPool(
                            minconn, maxconn, **self.db_config
                        )
                        print(f"[DB] Database connection pool initialized after restart")
                        return
                    except Exception as e2:
                        print(f"[DB] Failed to initialize pool after restart: {e2}")

            raise
```

**restart_postgresql() - Existing method (no changes needed):**
```python
def restart_postgresql(self):
    """Restart PostgreSQL if it's not responding"""
    print("[DB] PostgreSQL not responding, attempting to restart...")
    try:
        # Start PostgreSQL
        result = subprocess.run([
            '/opt/homebrew/opt/postgresql@16/bin/pg_ctl',
            '-D', '/opt/homebrew/var/postgresql@16',
            '-l', '/opt/homebrew/var/log/postgresql@16.log',
            'start'
        ], capture_output=True, text=True, timeout=10)

        if result.returncode == 0:
            print("[DB] PostgreSQL started successfully")
            time.sleep(2)  # Wait for PostgreSQL to be ready
            return True
        else:
            print(f"[DB] Failed to start PostgreSQL: {result.stderr}")
            return False
    except Exception as e:
        print(f"[DB] Error restarting PostgreSQL: {e}")
        return False
```

## app.py - Flask Server Startup

**startup_health_check() - New function:**
```python
def startup_health_check():
    """Perform health checks before starting the server"""
    logger.info("=" * 60)
    logger.info("Performing startup health checks...")
    logger.info("=" * 60)

    # Check 1: PostgreSQL is running
    logger.info("[HEALTH] Checking PostgreSQL status...")
    if not db.check_postgresql_running():
        logger.warning("[HEALTH] PostgreSQL is not running, attempting to start...")
        if db.restart_postgresql():
            logger.info("[HEALTH] PostgreSQL started successfully")
        else:
            logger.critical("[HEALTH] Failed to start PostgreSQL - server cannot start")
            sys.exit(1)
    else:
        logger.info("[HEALTH] PostgreSQL is running")

    # Check 2: Initialize database connection pool
    logger.info("[HEALTH] Initializing database connection pool...")
    try:
        db.initialize_pool()
        logger.info("[HEALTH] Database connection pool initialized successfully")
    except Exception as e:
        logger.critical(f"[HEALTH] Failed to initialize database pool: {e}")
        logger.critical("[HEALTH] Server cannot start without database connection")
        sys.exit(1)

    # Check 3: Test database connection
    logger.info("[HEALTH] Testing database connection...")
    try:
        conn = db.get_connection()
        db.return_connection(conn)
        logger.info("[HEALTH] Database connection test successful")
    except Exception as e:
        logger.critical(f"[HEALTH] Database connection test failed: {e}")
        sys.exit(1)

    logger.info("=" * 60)
    logger.info("[HEALTH] All startup checks passed!")
    logger.info("=" * 60)
```

**if __name__ == '__main__' - Updated startup:**
```python
if __name__ == '__main__':
    # Register signal handler
    signal.signal(signal.SIGTERM, handle_sigterm)

    # Perform startup health checks
    startup_health_check()

    # Log startup information
    logger.info("=" * 60)
    logger.info("Starting Firefly server")
    logger.info(f"Host: 0.0.0.0")
    logger.info(f"Port: 8080")
    logger.info(f"Debug mode: False")
    logger.info(f"Local IP: http://192.168.1.76:8080")
    logger.info(f"Public IP: http://185.96.221.52:8080")
    logger.info(f"Upload folder: {UPLOAD_FOLDER}")
    logger.info(f"Max file size: {app.config['MAX_CONTENT_LENGTH'] / (1024*1024):.0f}MB")
    logger.info("=" * 60)

    try:
        app.run(host='0.0.0.0', port=8080, debug=False)
    except Exception as e:
        logger.critical(f"Fatal error during server execution: {e}", exc_info=True)
        sys.exit(1)
    finally:
        logger.info("Server stopped")
```

## Successful Startup Log Output

```
============================================================
Performing startup health checks...
============================================================
[HEALTH] Checking PostgreSQL status...
[HEALTH] PostgreSQL is running
[HEALTH] Initializing database connection pool...
Database connection pool initialized: localhost:5432/firefly
[HEALTH] Database connection pool initialized successfully
[HEALTH] Testing database connection...
[HEALTH] Database connection test successful
============================================================
[HEALTH] All startup checks passed!
============================================================
============================================================
Starting Firefly server
Host: 0.0.0.0
Port: 8080
Debug mode: False
Local IP: http://192.168.1.76:8080
Public IP: http://185.96.221.52:8080
Upload folder: /Users/microserver/firefly-server/uploads
Max file size: 16MB
============================================================
```

## Failed Startup Example

If PostgreSQL is not running and can't be started:
```
[HEALTH] Checking PostgreSQL status...
[HEALTH] PostgreSQL is not running, attempting to start...
[DB] PostgreSQL not responding, attempting to restart...
[DB] Failed to start PostgreSQL: <error message>
[HEALTH] CRITICAL: Failed to start PostgreSQL - server cannot start
```

The server exits with code 1 instead of starting in a broken state.

## Thread Safety Demonstration

**Without lock** (old code):
```
Request 1: Checks pool is None → starts initializing
Request 2: Checks pool is None → starts initializing (RACE!)
Request 1: Creates pool → success
Request 2: Creates pool → CORRUPTION (overwrites Request 1's pool)
```

**With lock** (new code):
```
Request 1: Acquires lock → checks pool is None → starts initializing
Request 2: Waits for lock...
Request 1: Creates pool → releases lock
Request 2: Acquires lock → checks pool is NOT None → skips initialization ✓
```

## Dependencies

- `psycopg2` - PostgreSQL adapter
- `threading` - Standard library for thread locks
- `subprocess` - For executing pg_ctl commands
- `time` - For sleep delays after PostgreSQL restart

## Testing

**Test startup with PostgreSQL running:**
```bash
cd apps/firefly/product/server/imp/py
./start.sh
# Should see all health checks pass
```

**Test startup with PostgreSQL stopped:**
```bash
# Stop PostgreSQL manually
/opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 stop

# Try to start server
./start.sh
# Should automatically restart PostgreSQL and continue
```

**Test watchdog integration:**
```bash
# Stop PostgreSQL
/opt/homebrew/opt/postgresql@16/bin/pg_ctl -D /opt/homebrew/var/postgresql@16 stop

# Wait for watchdog (runs every minute)
tail -f watchdog.log
# Should see:
# "CRITICAL: PostgreSQL is down!"
# "Restarting PostgreSQL..."
# "PostgreSQL restarted successfully"
# "SUCCESS: Server recovered after PostgreSQL restart"
```

## Critical Implementation Notes

1. **Lock is instance variable**: `self._pool_lock` not class variable, in case multiple Database instances exist
2. **Double-check inside lock**: Prevents wasted work if another thread initialized while waiting
3. **`with` statement**: Automatically releases lock even if exception occurs
4. **Health checks use sys.exit(1)**: Clear failure code for monitoring/restart scripts
5. **Logging uses logger.critical()**: Highest severity for startup failures
6. **PostgreSQL restart delay**: 2-second sleep allows PostgreSQL to fully start before connection attempt
7. **Timeout on status check**: 5-second timeout prevents hanging if pg_ctl doesn't respond
8. **Absolute paths**: Use full path to pg_ctl binary (not in PATH in cron environment)
