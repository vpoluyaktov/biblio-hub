#!/bin/bash
# BiblioHub - Start the Docker Swarm stack
# Usage: ./start_stack.sh [service|--list]
#   Without arguments: starts the entire stack
#   With service name: starts a specific service
#   With --list: lists available services

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
    echo "  <service>   Start a specific service"
    echo "  --list      List available services"
    echo "  (none)      Start the entire stack"
    echo ""
    show_list
}

# Load environment variables from .env file if it exists
if [ -f "$HUB_DIR/.env" ]; then
    set -a
    source "$HUB_DIR/.env"
    set +a
fi

BIBLIO_HUB_HOSTNAME="${BIBLIO_HUB_HOSTNAME:-localhost}"
BIBLIO_HUB_PORT="${BIBLIO_HUB_PORT:-9900}"
HUB_URL="http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}"

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

# Function to get list of enabled services
get_enabled_services() {
    local enabled=""
    for service in $ALL_SERVICES; do
        if is_service_enabled "$service"; then
            enabled="$enabled $service"
        fi
    done
    echo "$enabled" | xargs
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

# Check if Docker Swarm is initialized
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "Docker Swarm is not active. Initializing..."
    docker swarm init
fi

# Function to create data directories
create_data_dirs() {
    mkdir -p "$HUB_DIR/data/abb_tts/db"
    mkdir -p "$HUB_DIR/data/abb_tts/temp"
    mkdir -p "$HUB_DIR/data/abb_tts/logs"
    mkdir -p "$HUB_DIR/data/abb_ia/db"
    mkdir -p "$HUB_DIR/data/abb_ia/output"
    mkdir -p "$HUB_DIR/data/abb_ia/temp"
    mkdir -p "$HUB_DIR/data/abb_ia/logs"
    mkdir -p "$HUB_DIR/data/tts_silero/models"
    mkdir -p "$HUB_DIR/data/tts_openvoice/models"
    mkdir -p "$HUB_DIR/data/tts_piper/models"
    mkdir -p "$HUB_DIR/data/opds/db"
    mkdir -p "$HUB_DIR/data/opds/books"
    mkdir -p "$HUB_DIR/data/biblio_auth/db"
    mkdir -p "$HUB_DIR/data/audiobookshelf/config"
    mkdir -p "$HUB_DIR/data/audiobookshelf/metadata"
    mkdir -p "$HUB_DIR/data/audiobookshelf/audiobooks"
    mkdir -p "$HUB_DIR/data/audiobookshelf/podcasts"
}

# Function to get service status
get_service_status() {
    local service=$1
    local full_name="${STACK_NAME}_${service}"
    
    local replicas=$(docker service ls --filter "name=${full_name}" --format "{{.Replicas}}" 2>/dev/null | head -1)
    
    if [ -z "$replicas" ]; then
        echo "Pending"
        return
    fi
    
    local current=$(echo "$replicas" | cut -d'/' -f1)
    local desired=$(echo "$replicas" | cut -d'/' -f2)
    
    if [ "$current" = "$desired" ] && [ "$current" != "0" ]; then
        echo "Ready"
    else
        local failed=$(docker service ps "${full_name}" --filter "desired-state=shutdown" --format "{{.Error}}" 2>/dev/null | wc -l)
        if [ "${failed:-0}" -gt 3 ]; then
            echo "Failed"
        else
            echo "Starting"
        fi
    fi
}

# Function to print service status table
print_status_table() {
    local has_failed=false
    local all_ready=true
    local enabled_services=$(get_enabled_services)
    
    printf "\033[H\033[J"
    
    echo "=========================================="
    echo "  BiblioHub - Service Status"
    echo "=========================================="
    echo ""
    printf "  %-20s %s\n" "SERVICE" "STATUS"
    echo "  ----------------------------------------"
    
    for service in $ALL_SERVICES; do
        if ! is_service_enabled "$service"; then
            printf "  %-20s %b\n" "$service" "\033[90m○ Disabled\033[0m"
            continue
        fi
        
        local status=$(get_service_status "$service")
        local status_icon=""
        
        case "$status" in
            "Ready")
                status_icon="\033[32m✓ Ready\033[0m"
                ;;
            "Starting")
                status_icon="\033[33m◐ Starting...\033[0m"
                all_ready=false
                ;;
            "Failed")
                status_icon="\033[31m✗ Failed\033[0m"
                has_failed=true
                ;;
            "Pending")
                status_icon="\033[90m○ Pending\033[0m"
                all_ready=false
                ;;
        esac
        
        printf "  %-20s %b\n" "$service" "$status_icon"
    done
    
    echo ""
    
    if [ "$has_failed" = true ]; then
        return 2
    elif [ "$all_ready" = true ]; then
        return 0
    else
        return 1
    fi
}

wait_for_service() {
    local service=$1
    local full_name="${STACK_NAME}_${service}"
    local MAX_WAIT=180
    local POLL_INTERVAL=3
    local start_time=$(date +%s)
    
    echo "Waiting for $service to be ready..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        local replicas=$(docker service ls --filter "name=${full_name}" --format "{{.Replicas}}" 2>/dev/null | head -1)
        
        if [ -n "$replicas" ]; then
            local current=$(echo "$replicas" | cut -d'/' -f1)
            local desired=$(echo "$replicas" | cut -d'/' -f2)
            
            if [ "$current" = "$desired" ] && [ "$current" != "0" ]; then
                echo "  ✓ $service is ready"
                return 0
            fi
            
            local failed=$(docker service ps "${full_name}" --filter "desired-state=shutdown" --format "{{.Error}}" 2>/dev/null | wc -l)
            if [ "${failed:-0}" -gt 3 ]; then
                echo "  ✗ $service failed to start"
                return 1
            fi
        fi
        
        if [ $elapsed -ge $MAX_WAIT ]; then
            echo "  ⚠ Timeout waiting for $service (${MAX_WAIT}s)"
            return 1
        fi
        
        sleep $POLL_INTERVAL
    done
}

# ============================================
# Start single service
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
    
    # Check if service is enabled
    if ! is_service_enabled "$TARGET_SERVICE"; then
        echo "Error: Service '$TARGET_SERVICE' is disabled in .env file"
        echo "Set ENABLE_${TARGET_SERVICE^^} to 'true' to enable it"
        exit 1
    fi
    
    echo "=========================================="
    echo "  BiblioHub - Starting Service"
    echo "=========================================="
    echo ""
    echo "Starting service: $TARGET_SERVICE"
    
    # Ensure data directories exist
    create_data_dirs
    
    # Scale service up if it exists
    if docker service ls --filter "name=${STACK_NAME}_${TARGET_SERVICE}" | grep -q "${STACK_NAME}_${TARGET_SERVICE}"; then
        docker service scale "${STACK_NAME}_${TARGET_SERVICE}=1"
    else
        echo "Service $TARGET_SERVICE not found in stack. Deploying full stack..."
        cd "$HUB_DIR"
        docker stack deploy -c stack.yaml --resolve-image always "$STACK_NAME"
    fi
    
    wait_for_service "$TARGET_SERVICE"
    exit $?
fi

# ============================================
# Start entire stack (default behavior)
# ============================================
echo "=========================================="
echo "  BiblioHub - Starting Stack"
echo "=========================================="

# Create data directories
echo ""
echo "Creating data directories..."
create_data_dirs
echo "  - data/abb_tts/db              (database)"
echo "  - data/abb_tts/temp            (temp files and audiobooks)"
echo "  - data/abb_tts/logs            (log files)"
echo "  - data/abb_ia/db               (database)"
echo "  - data/abb_ia/output           (completed audiobooks)"
echo "  - data/abb_ia/temp             (temp files)"
echo "  - data/abb_ia/logs             (log files)"
echo "  - data/tts_silero/models       (Silero TTS models cache)"
echo "  - data/tts_openvoice/models    (OpenVoice TTS models cache)"
echo "  - data/tts_piper/models        (Piper TTS models cache)"
echo "  - data/opds/db                 (database)"
echo "  - data/opds/books              (e-book library)"
echo "  - data/biblio_auth/db          (Biblio Auth database)"
echo "  - data/audiobookshelf/config   (AudiobookShelf config)"
echo "  - data/audiobookshelf/metadata (AudiobookShelf metadata)"
echo "  - data/audiobookshelf/audiobooks (audiobooks library)"
echo "  - data/audiobookshelf/podcasts (podcasts library)"

# Deploy the stack
echo ""
echo "Deploying stack '$STACK_NAME'..."
cd "$HUB_DIR"
docker stack deploy -c stack.yaml --resolve-image always "$STACK_NAME"

MAX_WAIT=180
POLL_INTERVAL=3
start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    print_status_table && status_code=0 || status_code=$?
    
    if [ $status_code -eq 0 ]; then
        echo "=========================================="
        echo "  ✓ BiblioHub is ready!"
        echo "=========================================="
        echo ""
        echo "  Access the hub at: $HUB_URL"
        echo ""
        echo "  Use './scripts/stop_stack.sh' to stop the stack"
        break
    elif [ $status_code -eq 2 ]; then
        echo "=========================================="
        echo "  ⚠ Some services failed to start"
        echo "=========================================="
        echo ""
        echo "  Check logs with: docker service logs <service_name>"
        echo "  Access the hub at: $HUB_URL"
        echo ""
        echo "  Use './scripts/stop_stack.sh' to stop the stack"
        break
    elif [ $elapsed -ge $MAX_WAIT ]; then
        echo "=========================================="
        echo "  ⚠ Timeout waiting for services (${MAX_WAIT}s)"
        echo "=========================================="
        echo ""
        echo "  Some services may still be starting."
        echo "  Check status with: docker stack services $STACK_NAME"
        echo "  Access the hub at: $HUB_URL"
        echo ""
        echo "  Use './scripts/stop_stack.sh' to stop the stack"
        break
    fi
    
    sleep $POLL_INTERVAL
done
