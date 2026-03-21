#!/bin/bash
# BiblioHub - Restart a service in the Docker Swarm stack
# Usage: ./restart_service.sh <service>
#   Restarts a specific service (stop + start)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"

ALL_SERVICES="biblio-auth nginx-gateway biblio-catalog abb-tts abb-ia tts-silero tts-openvoice tts-piper stress-silero audiobookshelf"

show_list() {
    echo "Available services:"
    for service in $ALL_SERVICES; do
        echo "  - $service"
    done
}

show_usage() {
    echo "Usage: $0 <service>"
    echo ""
    echo "Options:"
    echo "  <service>   Restart a specific service"
    echo ""
    show_list
}

# Check arguments
if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 1
fi

TARGET_SERVICE="$1"

# Validate service name
if ! echo "$ALL_SERVICES" | grep -qw "$TARGET_SERVICE"; then
    echo "Error: Unknown service '$TARGET_SERVICE'"
    echo ""
    show_list
    exit 1
fi

"$SCRIPT_DIR/stop_stack.sh" "$TARGET_SERVICE"
"$SCRIPT_DIR/start_stack.sh" "$TARGET_SERVICE"
