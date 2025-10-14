#!/bin/bash
# Setup PostgreSQL with pgvector on macOS

set -e

echo "🔧 Setting up PostgreSQL with pgvector for Firefly (macOS)"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install it first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install PostgreSQL 16
echo "🐘 Installing PostgreSQL 16..."
brew install postgresql@16

# Start PostgreSQL service
echo "🚀 Starting PostgreSQL..."
brew services start postgresql@16

# Add PostgreSQL to PATH for this session
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# Wait a moment for PostgreSQL to start
sleep 3

# Install pgvector
echo "📐 Installing pgvector extension..."
brew install pgvector

# Create database and user
echo "🔐 Creating database and user..."
psql postgres << EOF
-- Create user
CREATE USER firefly_user WITH PASSWORD 'firefly_pass';

-- Create database
CREATE DATABASE firefly OWNER firefly_user;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE firefly TO firefly_user;
EOF

# Run schema setup
echo "📊 Setting up database schema..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
psql -d firefly -f "$SCRIPT_DIR/schema.sql"

echo ""
echo "✅ Database setup complete!"
echo ""
echo "Database details:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: firefly"
echo "  User: firefly_user"
echo "  Password: firefly_pass"
echo ""
echo "Connection string:"
echo "  postgresql://firefly_user:firefly_pass@localhost:5432/firefly"
echo ""
echo "⚠️  IMPORTANT: Change the default password in production!"
echo ""
