#!/bin/sh
# Docker healthcheck script for VLC Streaming Server

# Get the port from environment variable or use default
PORT=${PORT:-8080}

# Try to connect to the health endpoint
wget --quiet --tries=1 --spider "http://127.0.0.1:${PORT}/health" || exit 1

echo "Health check passed on port ${PORT}"
exit 0
