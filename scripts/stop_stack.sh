#!/bin/bash
# BiblioHub - Stop the Docker Swarm stack
# Usage: ./stop_stack.sh [service|--list]
#   Without arguments: stops the entire stack
#   With service name: stops a specific service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"
STACK_NAME="bibliohub"

ALL_SERVICES="biblio-auth nginx-gateway biblio-catalog abb-tts abb-ia tts-silero tts-openvoice tts-piper stress-silero audiobookshelf"

show_list() {
    echo "Available services:"
    for service in $ALL_SERVICES; do
        echo "  - $service"
    done
}

show_usage() {
    echo "Usage: $0 [service|--list]"
    echo ""
    echo "Options:"
    echo "  <service>   Stop a specific service"
    echo "  --list      List available services"
    echo "  (none)      Stop the entire stack"
    echo ""
    show_list
}

# Handle --list flag
if [ "$1" = "--list" ]; then
    show_list
    exit 0
fi

# Handle --help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

# ============================================
# Stop single service
# ============================================
if [ -n "$1" ]; then
    TARGET_SERVICE="$1"
    
    # Validate service name
    if ! echo "$ALL_SERVICES" | grep -qw "$TARGET_SERVICE"; then
        echo "Error: Unknown service '$TARGET_SERVICE'"
        echo ""
        show_list
        exit 1
    fi
    
    echo "=========================================="
    echo "  BiblioHub - Stopping Service"
    echo "=========================================="
    echo ""
    echo "Stopping service: $TARGET_SERVICE"
    
    docker service scale "${STACK_NAME}_${TARGET_SERVICE}=0"
    
    echo ""
    echo "  ✓ $TARGET_SERVICE stopped"
    exit 0
fi

# ============================================
# Stop entire stack (default behavior)
# ============================================
echo "=========================================="
echo "  BiblioHub - Stopping Stack"
echo "=========================================="

# Check if stack exists
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo "Stack '$STACK_NAME' is not running."
    exit 0
fi

echo ""
echo "Removing stack '$STACK_NAME'..."
docker stack rm "$STACK_NAME"

echo ""
echo "Waiting for services to stop..."
sleep 5

# Wait for networks to be removed
echo "Waiting for networks to be cleaned up..."
while docker network ls | grep -q "${STACK_NAME}_"; do
    sleep 2
done

echo ""
echo "=========================================="
echo "  BiblioHub stack stopped successfully!"
echo "=========================================="
echo ""
echo "Note: Volumes are preserved. To remove them, run:"
echo "  docker volume rm \$(docker volume ls -q | grep ${STACK_NAME})"
