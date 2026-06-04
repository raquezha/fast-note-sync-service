#!/bin/bash
set -e

# Northflank assigns the port dynamically using the PORT environment variable
export PORT=${PORT:-9000}
# Ensure the port starts with ":" for the Go app config
if [[ $PORT != :* ]]; then
    export PORT=":$PORT"
fi

export RUN_MODE=${RUN_MODE:-release}
export DB_TYPE=${DB_TYPE:-postgres}
export DB_SSL_MODE=${DB_SSL_MODE:-require}

# Auto-generate secure AUTH_TOKEN_KEY if not provided
if [ -z "$AUTH_TOKEN_KEY" ]; then
    echo "Warning: AUTH_TOKEN_KEY not set. Generating a random key..."
    export AUTH_TOKEN_KEY=$(openssl rand -base64 32)
fi

# Ensure directories exist
mkdir -p /fast-note-sync/config
mkdir -p /fast-note-sync/storage/database
mkdir -p /fast-note-sync/storage/logs

echo "Injecting environment variables into config.yaml..."
envsubst < /fast-note-sync/config.yaml.template > /fast-note-sync/config/config.yaml

echo "Starting Fast Note Sync Service..."
exec /fast-note-sync/fast-note-sync-service run -c /fast-note-sync/config/config.yaml
