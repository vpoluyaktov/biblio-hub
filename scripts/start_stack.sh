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

# Create data directories
echo ""
echo "Creating data directories..."
mkdir -p "$HUB_DIR/data/abb_tts/db"
mkdir -p "$HUB_DIR/data/abb_tts/temp"
mkdir -p "$HUB_DIR/data/tts_silero/models"
mkdir -p "$HUB_DIR/data/opds/db"
mkdir -p "$HUB_DIR/data/opds/books"
echo "  - data/abb_tts/db      (database)"
echo "  - data/abb_tts/temp    (temp files and audiobooks)"
echo "  - data/tts_silero/models (TTS models cache)"
echo "  - data/opds/db           (database)"
echo "  - data/opds/books        (e-book library)"

# Deploy the stack
echo ""
echo "Deploying stack '$STACK_NAME'..."
cd "$HUB_DIR"
docker stack deploy -c stack.yaml "$STACK_NAME"

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
echo "  - ABB_TTS:         http://localhost:9901"
echo "  - TTS_SILERO:      http://localhost:9902"
echo "  - OPDS Server:     http://localhost:9903"
echo ""
echo "Use './scripts/stop_stack.sh' to stop the stack"
