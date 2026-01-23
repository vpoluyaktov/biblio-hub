#!/bin/bash
# BiblioHub - Rebuild all Docker images and push to Docker Hub
# This script rebuilds all service images and pushes them with dev-latest tag

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"

# Docker Hub username
DOCKER_USER="vpoluyaktov"
TAG="dev-latest"

echo "=========================================="
echo "  BiblioHub - Rebuilding Docker Images"
echo "=========================================="
echo "Docker Hub user: $DOCKER_USER"
echo "Tag: $TAG"

# Check if logged in to Docker Hub
if ! docker info 2>/dev/null | grep -q "Username: $DOCKER_USER"; then
    echo ""
    echo "Not logged in to Docker Hub. Please log in:"
    docker login --username "$DOCKER_USER"
fi

# Build Gateway (nginx with landing page)
echo ""
echo "[1/4] Building bibliohub-gateway..."
echo "----------------------------------------------"
docker build -t "$DOCKER_USER/bibliohub-gateway:$TAG" "$HUB_DIR/nginx"

# Build Audiobook Builder TTS (ABB_TTS)
echo ""
echo "[2/4] Building biblio-audiobook-builder-tts..."
echo "----------------------------------------------"
docker build -t "$DOCKER_USER/bibliohub-audiobook-builder-tts:$TAG" "$HUB_DIR/../biblio-audiobook-builder-tts"

# Build TTS Server Silero (TTS_SILERO)
echo ""
echo "[3/4] Building biblio-tts-server-silero..."
echo "----------------------------------------------"
docker build -t "$DOCKER_USER/bibliohub-tts-server-silero:$TAG" -f "$HUB_DIR/../biblio-tts-server-silero/docker/Dockerfile" "$HUB_DIR/../biblio-tts-server-silero"

# Build OPDS Server
echo ""
echo "[4/4] Building biblio-opds-server..."
echo "----------------------------------------------"
docker build -t "$DOCKER_USER/bibliohub-opds-server:$TAG" -f "$HUB_DIR/../biblio-opds-server/docker/Dockerfile" "$HUB_DIR/../biblio-opds-server"

echo ""
echo "=========================================="
echo "  All images rebuilt successfully!"
echo "=========================================="

# Push to Docker Hub
echo ""
echo "=========================================="
echo "  Pushing images to Docker Hub..."
echo "=========================================="

echo ""
echo "[1/4] Pushing bibliohub-gateway..."
docker push "$DOCKER_USER/bibliohub-gateway:$TAG"

echo ""
echo "[2/4] Pushing bibliohub-audiobook-builder-tts..."
docker push "$DOCKER_USER/bibliohub-audiobook-builder-tts:$TAG"

echo ""
echo "[3/4] Pushing bibliohub-tts-server-silero..."
docker push "$DOCKER_USER/bibliohub-tts-server-silero:$TAG"

echo ""
echo "[4/4] Pushing bibliohub-opds-server..."
docker push "$DOCKER_USER/bibliohub-opds-server:$TAG"

echo ""
echo "=========================================="
echo "  All images pushed to Docker Hub!"
echo "=========================================="

# Note: Docker Hub descriptions can be set manually at:
#   https://hub.docker.com/r/vpoluyaktov/bibliohub-gateway
#   https://hub.docker.com/r/vpoluyaktov/bibliohub-audiobook-builder-tts
#   https://hub.docker.com/r/vpoluyaktov/bibliohub-tts-server-silero
#   https://hub.docker.com/r/vpoluyaktov/bibliohub-opds-server

echo ""
echo "Images available:"
echo "  - $DOCKER_USER/bibliohub-gateway:$TAG"
echo "  - $DOCKER_USER/bibliohub-audiobook-builder-tts:$TAG"
echo "  - $DOCKER_USER/bibliohub-tts-server-silero:$TAG"
echo "  - $DOCKER_USER/bibliohub-opds-server:$TAG"
