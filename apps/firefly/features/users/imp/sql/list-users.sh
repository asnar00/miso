#!/bin/bash
# List all users in the Firefly database

# Set default database connection parameters
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-5432}"
export DB_NAME="${DB_NAME:-firefly}"
export DB_USER="${DB_USER:-firefly_user}"
export DB_PASSWORD="${DB_PASSWORD:-firefly_pass}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the Python script
python3 "$SCRIPT_DIR/list-users.py"
