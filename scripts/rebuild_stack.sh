#!/bin/bash
# BiblioHub - Rebuild all Docker images
# This script rebuilds all service images from their respective repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  BiblioHub - Rebuilding Docker Images"
echo "=========================================="

# Build Audiobook Builder TTS (ABB_TTS)
echo ""
echo "[1/3] Building biblio-audiobook-builder-tts (ABB_TTS)..."
echo "----------------------------------------------"
docker build -t biblio-audiobook-builder-tts:latest "$HUB_DIR/../biblio-audiobook-builder-tts"

# Build TTS Server Silero (TTS_SILERO)
echo ""
echo "[2/3] Building biblio-tts-server-silero (TTS_SILERO)..."
echo "----------------------------------------------"
docker build -t biblio-tts-server-silero:latest -f "$HUB_DIR/../biblio-tts-server-silero/docker/Dockerfile" "$HUB_DIR/../biblio-tts-server-silero"

# Build OPDS Server
echo ""
echo "[3/3] Building biblio-opds-server..."
echo "----------------------------------------------"
docker build -t biblio-opds-server:latest -f "$HUB_DIR/../biblio-opds-server/docker/Dockerfile" "$HUB_DIR/../biblio-opds-server"

echo ""
echo "=========================================="
echo "  All images rebuilt successfully!"
echo "=========================================="
echo ""
echo "Images built:"
docker images | grep -E "biblio-(audiobook-builder-tts|tts-server-silero|opds-server)" | head -3
