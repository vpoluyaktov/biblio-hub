#!/bin/bash
# BiblioHub - Start the Docker Swarm stack
# This script deploys the BiblioHub stack to Docker Swarm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"
STACK_NAME="bibliohub"

# Load environment variables from .env file if it exists
if [ -f "$HUB_DIR/.env" ]; then
    echo "Loading environment from .env file..."
    set -a  # automatically export all variables
    source "$HUB_DIR/.env"
    set +a
fi

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
mkdir -p "$HUB_DIR/data/abb_tts/logs"
mkdir -p "$HUB_DIR/data/tts_silero/models"
mkdir -p "$HUB_DIR/data/tts_openvoice/models"
mkdir -p "$HUB_DIR/data/opds/db"
mkdir -p "$HUB_DIR/data/opds/books"
mkdir -p "$HUB_DIR/data/keycloak/db"
echo "  - data/abb_tts/db              (database)"
echo "  - data/abb_tts/temp            (temp files and audiobooks)"
echo "  - data/abb_tts/logs            (log files)"
echo "  - data/tts_silero/models       (Silero TTS models cache)"
echo "  - data/tts_openvoice/models    (OpenVoice TTS models cache)"
echo "  - data/opds/db                 (database)"
echo "  - data/opds/books              (e-book library)"
echo "  - data/keycloak/db             (Keycloak database)"

# Deploy the stack (--resolve-image always forces pulling latest images)
echo ""
echo "Deploying stack '$STACK_NAME'..."
cd "$HUB_DIR"
docker stack deploy -c stack.yaml --resolve-image always "$STACK_NAME"

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
echo "  - TTS_OPENVOICE:   http://localhost:9904"
echo ""
echo "Use './scripts/stop_stack.sh' to stop the stack"
