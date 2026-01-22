#!/bin/bash
# BiblioHub - Start the Docker Swarm stack
# This script deploys the BiblioHub stack to Docker Swarm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"
STACK_NAME="bibliohub"

echo "=========================================="
echo "  BiblioHub - Starting Stack"
echo "=========================================="

# Check if Docker Swarm is initialized
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "Docker Swarm is not active. Initializing..."
    docker swarm init
fi

# Deploy the stack
echo ""
echo "Deploying stack '$STACK_NAME'..."
docker stack deploy -c "$HUB_DIR/stack.yaml" "$STACK_NAME"

echo ""
echo "Waiting for services to start..."
sleep 5

echo ""
echo "=========================================="
echo "  Stack Status"
echo "=========================================="
docker stack services "$STACK_NAME"

echo ""
echo "=========================================="
echo "  BiblioHub is starting!"
echo "=========================================="
echo ""
echo "Access points:"
echo "  - Landing Page:    http://localhost:9900"
echo "  - ABB_TTS:         http://localhost:9900/abb-tts/"
echo "  - TTS_SILERO:      http://localhost:9900/tts-silero/"
echo "  - OPDS Server:     http://localhost:9900/opds/"
echo ""
echo "Use './scripts/stop_stack.sh' to stop the stack"
