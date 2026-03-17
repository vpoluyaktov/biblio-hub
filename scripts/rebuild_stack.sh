#!/bin/bash
# BiblioHub - Rebuild Docker images and push to Docker Hub
# This script rebuilds service images and pushes them with dev-latest tag
#
# Usage:
#   ./rebuild_stack.sh                    # Build all components (default)
#   ./rebuild_stack.sh gateway auth       # Build specific components
#   ./rebuild_stack.sh tts-piper abb-tts  # Build Piper TTS and ABB-TTS
#   ./rebuild_stack.sh --help             # Show help
#
# Available components:
#   gateway       - Nginx gateway + landing page
#   auth          - Biblio Auth
#   abb-tts       - Audiobook Builder TTS
#   catalog       - Biblio Catalog (OPDS)
#   tts-silero    - Silero TTS Server
#   tts-openvoice - OpenVoice TTS Server
#   tts-piper     - Piper TTS Server
#   stress-silero - Stress Server Silero
#   all           - All components (default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"

# Docker Hub username
DOCKER_USER="vpoluyaktov"
TAG="dev-latest"

# Component definitions
declare -A COMPONENTS
COMPONENTS[gateway]="Gateway (nginx + landing page)|$HUB_DIR/nginx|bibliohub-gateway"
COMPONENTS[auth]="Biblio Auth|$HUB_DIR/../biblio-auth|bibliohub-auth|docker/Dockerfile"
COMPONENTS[abb-tts]="Audiobook Builder TTS|$HUB_DIR/../biblio-audiobook-builder-tts|bibliohub-audiobook-builder-tts"
COMPONENTS[abb-ia]="Audiobook Builder IA|$HUB_DIR/../biblio-audiobook-builder-ia|bibliohub-audiobook-builder-ia"
COMPONENTS[tts-silero]="Silero TTS Server|$HUB_DIR/../biblio-tts-server-silero|bibliohub-tts-server-silero|docker/Dockerfile"
COMPONENTS[tts-openvoice]="OpenVoice TTS Server|$HUB_DIR/../biblio-tts-server-openvoice|bibliohub-tts-server-openvoice|docker/Dockerfile"
COMPONENTS[tts-piper]="Piper TTS Server|$HUB_DIR/../biblio-tts-server-piper|bibliohub-tts-server-piper|docker/Dockerfile"
COMPONENTS[catalog]="Biblio Catalog|$HUB_DIR/../biblio-ebooks-catalog|bibliohub-catalog|docker/Dockerfile"
COMPONENTS[stress-silero]="Stress Server Silero|$HUB_DIR/../biblio-stress-server-silero|bibliohub-stress-server-silero|docker/Dockerfile"

# Parse command line arguments
SELECTED_COMPONENTS=()
if [ $# -eq 0 ]; then
    # No arguments - build all
    SELECTED_COMPONENTS=(gateway auth abb-tts abb-ia tts-silero tts-openvoice tts-piper catalog stress-silero)
else
    # Check for help
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage: $0 [component1] [component2] ..."
        echo ""
        echo "Available components:"
        for comp in gateway auth abb-tts abb-ia catalog tts-silero tts-openvoice tts-piper stress-silero; do
            IFS='|' read -r name path image dockerfile <<< "${COMPONENTS[$comp]}"
            printf "  %-15s - %s\n" "$comp" "$name"
        done
        echo ""
        echo "Examples:"
        echo "  $0                          # Build all components"
        echo "  $0 tts-piper                # Build only Piper TTS"
        echo "  $0 tts-piper abb-tts        # Build Piper TTS and ABB-TTS"
        echo "  $0 gateway auth catalog     # Build gateway, auth, and catalog"
        exit 0
    fi
    
    # Validate and collect components
    for arg in "$@"; do
        if [ "$arg" = "all" ]; then
            SELECTED_COMPONENTS=(gateway auth abb-tts abb-ia tts-silero tts-openvoice tts-piper catalog stress-silero)
            break
        elif [ -n "${COMPONENTS[$arg]}" ]; then
            SELECTED_COMPONENTS+=("$arg")
        else
            echo "Error: Unknown component '$arg'"
            echo "Run '$0 --help' to see available components"
            exit 1
        fi
    done
fi

echo "=========================================="
echo "  BiblioHub - Rebuilding Docker Images"
echo "=========================================="
echo "Docker Hub user: $DOCKER_USER"
echo "Tag: $TAG"
echo ""
echo "Building ${#SELECTED_COMPONENTS[@]} component(s): ${SELECTED_COMPONENTS[*]}"
echo ""

# Check if logged in to Docker Hub
if ! docker info 2>/dev/null | grep -q "Username: $DOCKER_USER"; then
    echo ""
    echo "Not logged in to Docker Hub. Please log in:"
    docker login --username "$DOCKER_USER"
fi

# Build selected components
BUILT_IMAGES=()
for i in "${!SELECTED_COMPONENTS[@]}"; do
    comp="${SELECTED_COMPONENTS[$i]}"
    IFS='|' read -r name path image dockerfile <<< "${COMPONENTS[$comp]}"
    
    echo ""
    echo "[$((i+1))/${#SELECTED_COMPONENTS[@]}] Building $name..."
    echo "----------------------------------------------"
    
    if [ -n "$dockerfile" ]; then
        docker build -t "$DOCKER_USER/$image:$TAG" -f "$path/$dockerfile" "$path"
    else
        docker build -t "$DOCKER_USER/$image:$TAG" "$path"
    fi
    
    BUILT_IMAGES+=("$DOCKER_USER/$image:$TAG")
done

echo ""
echo "=========================================="
echo "  All images rebuilt successfully!"
echo "=========================================="

# Push to Docker Hub
echo ""
echo "=========================================="
echo "  Pushing images to Docker Hub..."
echo "=========================================="

for i in "${!BUILT_IMAGES[@]}"; do
    image="${BUILT_IMAGES[$i]}"
    echo ""
    echo "[$((i+1))/${#BUILT_IMAGES[@]}] Pushing ${image##*/}..."
    docker push "$image"
done

echo ""
echo "=========================================="
echo "  All images pushed to Docker Hub!"
echo "=========================================="

echo ""
echo "Images available:"
for image in "${BUILT_IMAGES[@]}"; do
    echo "  - $image"
done

echo ""
echo "To restart services with new images:"
echo "  docker service update --image <image> bibliohub_<service>"
echo ""
echo "Or restart the entire stack:"
echo "  ./scripts/stop_stack.sh && ./scripts/start_stack.sh"
