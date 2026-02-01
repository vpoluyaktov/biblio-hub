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

# Set defaults for hub URL
BIBLIO_HUB_HOSTNAME="${BIBLIO_HUB_HOSTNAME:-localhost}"
BIBLIO_HUB_PORT="${BIBLIO_HUB_PORT:-9900}"
HUB_URL="http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}"

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
mkdir -p "$HUB_DIR/data/biblio_auth/db"
echo "  - data/abb_tts/db              (database)"
echo "  - data/abb_tts/temp            (temp files and audiobooks)"
echo "  - data/abb_tts/logs            (log files)"
echo "  - data/tts_silero/models       (Silero TTS models cache)"
echo "  - data/tts_openvoice/models    (OpenVoice TTS models cache)"
echo "  - data/opds/db                 (database)"
echo "  - data/opds/books              (e-book library)"
echo "  - data/biblio_auth/db          (Biblio Auth database)"

# Deploy the stack (--resolve-image always forces pulling latest images)
echo ""
echo "Deploying stack '$STACK_NAME'..."
cd "$HUB_DIR"
docker stack deploy -c stack.yaml --resolve-image always "$STACK_NAME"

# All services to monitor
ALL_SERVICES="biblio-auth nginx-gateway biblio-catalog abb-tts tts-silero tts-openvoice"
MAX_WAIT=180  # Maximum wait time in seconds
POLL_INTERVAL=3

# Function to get service status
get_service_status() {
    local service=$1
    local full_name="${STACK_NAME}_${service}"
    
    # Get replicas in format "current/desired"
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
        # Check for failed tasks (more than 3 failed attempts)
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
    
    # Clear screen and move cursor to top
    printf "\033[H\033[J"
    
    echo "=========================================="
    echo "  BiblioHub - Service Status"
    echo "=========================================="
    echo ""
    printf "  %-20s %s\n" "SERVICE" "STATUS"
    echo "  ----------------------------------------"
    
    for service in $ALL_SERVICES; do
        local status=$(get_service_status "$service")
        local status_icon=""
        
        case "$status" in
            "Ready")
                status_icon="\033[32m✓ Ready\033[0m"      # Green
                ;;
            "Starting")
                status_icon="\033[33m◐ Starting...\033[0m" # Yellow
                all_ready=false
                ;;
            "Failed")
                status_icon="\033[31m✗ Failed\033[0m"      # Red
                has_failed=true
                ;;
            "Pending")
                status_icon="\033[90m○ Pending\033[0m"     # Gray
                all_ready=false
                ;;
        esac
        
        printf "  %-20s %b\n" "$service" "$status_icon"
    done
    
    echo ""
    
    # Return status: 0=all ready, 1=still starting, 2=has failures
    if [ "$has_failed" = true ]; then
        return 2
    elif [ "$all_ready" = true ]; then
        return 0
    else
        return 1
    fi
}

echo ""
start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Capture status code without triggering set -e
    print_status_table && status_code=0 || status_code=$?
    
    if [ $status_code -eq 0 ]; then
        # All services ready
        echo "=========================================="
        echo "  ✓ BiblioHub is ready!"
        echo "=========================================="
        echo ""
        echo "  Access the hub at: $HUB_URL"
        echo ""
        echo "  Use './scripts/stop_stack.sh' to stop the stack"
        break
    elif [ $status_code -eq 2 ]; then
        # Has failures
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
        # Timeout
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
