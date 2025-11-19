# database-pool
*Thread-safe database connection pool with startup health checks*

The database connection pool manages PostgreSQL connections for the Flask server, ensuring thread-safe initialization and startup verification before accepting requests.

## Startup Health Checks

Before the server starts accepting requests, it performs these checks:

1. **PostgreSQL status**: Verifies PostgreSQL is running (starts it if needed)
2. **Pool initialization**: Creates connection pool eagerly during startup
3. **Connection test**: Tests a database connection to verify everything works

**Fail-fast behavior**: If any check fails, the server exits immediately rather than starting in a broken state.

## Thread Safety

The connection pool uses a threading lock to prevent race conditions when multiple requests try to initialize the pool simultaneously. This prevents pool corruption that can occur when PostgreSQL is temporarily unavailable.

**Double-check pattern**: Inside the lock, the code verifies the pool hasn't already been initialized by another thread.

## Connection Pool Lifecycle

**Initialization**: Pool is created during startup with 1-10 connections
**Usage**: Requests get connections from the pool, use them, then return them
**Recovery**: If a connection is corrupted, it's closed and the pool is reset
**Restart**: If PostgreSQL goes down, the pool automatically restarts it and reconnects

## Why This Matters

**The Problem**: Without these protections, when PostgreSQL isn't running:
- Server starts anyway
- Multiple requests hit simultaneously
- All try to initialize pool at once
- Race condition → pool corruption → crash

**The Solution**:
- Startup checks prevent server from starting without database
- Thread safety prevents concurrent initialization
- Fail-fast ensures clean error states instead of corruption
