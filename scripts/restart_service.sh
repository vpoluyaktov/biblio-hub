#!/bin/bash
# BiblioHub - Restart a service in the Docker Swarm stack
# Usage: ./restart_service.sh <service>
#   Restarts a specific service (stop + start)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"

ALL_SERVICES="biblio-auth nginx-gateway biblio-catalog abb-tts abb-ia tts-silero tts-openvoice tts-piper stress-silero audiobookshelf"

# Load environment variables from .env file if it exists
if [ -f "$HUB_DIR/.env" ]; then
    set -a
    source "$HUB_DIR/.env"
    set +a
fi

# Function to check if a service is enabled
is_service_enabled() {
    local service=$1
    
    # nginx-gateway is always enabled
    if [ "$service" = "nginx-gateway" ]; then
        return 0
    fi
    
    # Map service names to environment variables
    case "$service" in
        "biblio-auth")
            [ "${ENABLE_BIBLIO_AUTH:-true}" = "true" ]
            ;;
        "biblio-catalog")
            [ "${ENABLE_BIBLIO_CATALOG:-true}" = "true" ]
            ;;
        "abb-tts")
            [ "${ENABLE_ABB_TTS:-true}" = "true" ]
            ;;
        "abb-ia")
            [ "${ENABLE_ABB_IA:-true}" = "true" ]
            ;;
        "tts-silero")
            [ "${ENABLE_TTS_SILERO:-true}" = "true" ]
            ;;
        "tts-openvoice")
            [ "${ENABLE_TTS_OPENVOICE:-true}" = "true" ]
            ;;
        "tts-piper")
            [ "${ENABLE_TTS_PIPER:-true}" = "true" ]
            ;;
        "stress-silero")
            [ "${ENABLE_STRESS_SILERO:-true}" = "true" ]
            ;;
        "audiobookshelf")
            [ "${ENABLE_AUDIOBOOKSHELF:-true}" = "true" ]
            ;;
        *)
            return 0
            ;;
    esac
}

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

# Check if service is enabled
if ! is_service_enabled "$TARGET_SERVICE"; then
    echo "Error: Service '$TARGET_SERVICE' is disabled in .env file"
    echo "Set ENABLE_${TARGET_SERVICE^^} to 'true' to enable it"
    exit 1
fi

"$SCRIPT_DIR/stop_stack.sh" "$TARGET_SERVICE"
"$SCRIPT_DIR/start_stack.sh" "$TARGET_SERVICE"
