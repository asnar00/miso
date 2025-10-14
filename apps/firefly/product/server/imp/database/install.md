# Database Installation Guide

*Step-by-step instructions for setting up PostgreSQL with pgvector on the Firefly server*

This guide covers installing PostgreSQL 16+ with the pgvector extension for semantic search on vector embeddings.

## Prerequisites

- macOS server (tested on Mac Mini with macOS Sonoma)
- SSH access with sudo privileges
- Homebrew (will be installed if not present)

## Installation Steps

### 1. Install Homebrew (if not already installed)

```bash
ssh your-server

# Install Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH for current session
eval "$(/opt/homebrew/bin/brew shellenv)"

# Add to shell profile for future sessions
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
```

### 2. Install PostgreSQL 16

```bash
# Install PostgreSQL 16
brew install postgresql@16

# Start PostgreSQL service
brew services start postgresql@16

# Add PostgreSQL to PATH
echo 'export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"' >> ~/.zshrc
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
```

### 3. Build and Install pgvector Extension

The Homebrew pgvector package is built for PostgreSQL 17+, so we need to build from source for PostgreSQL 16:

```bash
# Install build dependencies (if needed)
xcode-select --install  # May already be installed

# Clone pgvector repository
cd /tmp
git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git
cd pgvector

# Build and install for PostgreSQL 16
export PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
make
make install

# Verify installation
ls /opt/homebrew/opt/postgresql@16/lib/postgresql/vector.dylib
ls /opt/homebrew/opt/postgresql@16/share/postgresql@16/extension/vector.control
```

### 4. Create Database and User

```bash
# Connect to PostgreSQL as default user
psql postgres

# Run these SQL commands:
```

```sql
-- Create user
CREATE USER firefly_user WITH PASSWORD 'firefly_pass';

-- Create database
CREATE DATABASE firefly OWNER firefly_user;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE firefly TO firefly_user;

-- Exit psql
\q
```

### 5. Run Schema Migration

```bash
# Upload schema.sql to server (from your local machine)
scp schema.sql your-server:~/firefly-server/

# On the server, run the schema
cd ~/firefly-server
psql -d firefly -f schema.sql

# Grant permissions on tables
psql -d firefly -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO firefly_user;'
psql -d firefly -c 'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO firefly_user;'
```

### 6. Install Python Dependencies

```bash
cd ~/firefly-server
pip3 install -r requirements.txt
```

### 7. Test Database Connection

```bash
# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=firefly
export DB_USER=firefly_user
export DB_PASSWORD=firefly_pass

# Run test script
python3 test_db.py
```

If all tests pass, the database is ready!

## Connection Configuration

### Environment Variables

The Python database module (`db.py`) reads these environment variables:

```bash
DB_HOST=localhost      # Database host
DB_PORT=5432          # PostgreSQL port
DB_NAME=firefly       # Database name
DB_USER=firefly_user  # Database user
DB_PASSWORD=firefly_pass  # User password
```

### Connection String

```
postgresql://firefly_user:firefly_pass@localhost:5432/firefly
```

## Verification

After installation, verify everything works:

```bash
# Check PostgreSQL is running
brew services list | grep postgresql@16

# Connect to database
psql -d firefly -U firefly_user -h localhost

# In psql, test pgvector extension
\dx vector

# Should show:
#  Name   | Version | Schema |         Description
# --------+---------+--------+------------------------------
#  vector | 0.8.1   | public | vector data type and ivfflat and hnsw access methods
```

## Troubleshooting

### pgvector extension not found

**Error**: `extension "vector" is not available`

**Solution**: Make sure pgvector is built and installed for PostgreSQL 16:
```bash
export PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
cd /tmp/pgvector
make clean
make
make install
```

### Permission denied for table

**Error**: `permission denied for table users` or `permission denied for table posts`

**Solution**: Grant permissions to firefly_user:
```bash
psql -d firefly -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO firefly_user;'
psql -d firefly -c 'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO firefly_user;'
```

### Library version mismatch

**Error**: `incompatible library version mismatch`

**Solution**: pgvector was built for wrong PostgreSQL version. Rebuild from source with correct PG_CONFIG.

### PostgreSQL not starting

```bash
# Check logs
brew services info postgresql@16

# Restart service
brew services restart postgresql@16

# Check if port 5432 is in use
lsof -i :5432
```

## Security Notes

**⚠️ IMPORTANT**: The default password (`firefly_pass`) is for development only.

For production:
1. Change the database password:
   ```sql
   ALTER USER firefly_user WITH PASSWORD 'your-secure-password';
   ```

2. Update environment variables with new password

3. Consider using PostgreSQL's `.pgpass` file or connection URI in environment

4. Restrict database access by IP if needed in `pg_hba.conf`

## Maintenance

### Start/Stop PostgreSQL

```bash
# Start
brew services start postgresql@16

# Stop
brew services stop postgresql@16

# Restart
brew services restart postgresql@16

# Status
brew services info postgresql@16
```

### Backup Database

```bash
# Backup
pg_dump -U firefly_user -h localhost firefly > firefly_backup.sql

# Restore
psql -U firefly_user -h localhost firefly < firefly_backup.sql
```

### Reset Database

```bash
# Drop and recreate (WARNING: destroys all data)
psql postgres -c "DROP DATABASE firefly;"
psql postgres -c "CREATE DATABASE firefly OWNER firefly_user;"
psql -d firefly -f schema.sql
```
