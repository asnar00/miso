#!/bin/bash
# Setup PostgreSQL with pgvector on the server

set -e

echo "🔧 Setting up PostgreSQL with pgvector for Firefly"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script needs sudo privileges. Please run with sudo or as root."
    exit 1
fi

# Update package list
echo "📦 Updating package list..."
apt-get update -qq

# Install PostgreSQL 16
echo "🐘 Installing PostgreSQL 16..."
apt-get install -y postgresql-16 postgresql-client-16 postgresql-contrib-16

# Install build dependencies for pgvector
echo "🔨 Installing build dependencies..."
apt-get install -y postgresql-server-dev-16 git build-essential

# Build and install pgvector
echo "📐 Installing pgvector extension..."
cd /tmp
if [ -d "pgvector" ]; then
    rm -rf pgvector
fi
git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
cd pgvector
make
make install

# Start PostgreSQL if not running
echo "🚀 Starting PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Create database and user
echo "🔐 Creating database and user..."
sudo -u postgres psql << EOF
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
sudo -u postgres psql -d firefly -f "$SCRIPT_DIR/schema.sql"

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
