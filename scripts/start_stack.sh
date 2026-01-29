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

# Define services to monitor (excluding replicated GPU services that scale dynamically)
CORE_SERVICES="keycloak-db keycloak nginx-gateway opds-server abb-tts"
MAX_WAIT=180  # Maximum wait time in seconds
POLL_INTERVAL=5

echo ""
echo "=========================================="
echo "  Waiting for services to start..."
echo "=========================================="
echo ""

start_time=$(date +%s)
all_ready=false

while [ "$all_ready" = false ]; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $MAX_WAIT ]; then
        echo ""
        echo "⚠️  Timeout waiting for services (${MAX_WAIT}s). Some services may still be starting."
        echo "    Check status with: docker stack services $STACK_NAME"
        break
    fi
    
    all_ready=true
    status_line=""
    
    for service in $CORE_SERVICES; do
        full_name="${STACK_NAME}_${service}"
        # Get replicas in format "current/desired"
        replicas=$(docker service ls --filter "name=${full_name}" --format "{{.Replicas}}" 2>/dev/null | head -1)
        
        if [ -z "$replicas" ]; then
            status_line="${status_line}${service}: ⏳  "
            all_ready=false
        else
            current=$(echo "$replicas" | cut -d'/' -f1)
            desired=$(echo "$replicas" | cut -d'/' -f2)
            
            if [ "$current" = "$desired" ] && [ "$current" != "0" ]; then
                status_line="${status_line}${service}: ✓  "
            else
                status_line="${status_line}${service}: ${current}/${desired}  "
                all_ready=false
            fi
        fi
    done
    
    # Print status on same line (overwrite)
    printf "\r%-100s" "$status_line"
    
    if [ "$all_ready" = false ]; then
        sleep $POLL_INTERVAL
    fi
done

echo ""
echo ""

if [ "$all_ready" = true ]; then
    echo "=========================================="
    echo "  ✓ BiblioHub is ready!"
    echo "=========================================="
    echo ""
    echo "  Access the hub at: http://localhost:9900"
    echo ""
    echo "  Use './scripts/stop_stack.sh' to stop the stack"
else
    echo ""
    echo "  Partial startup - access the hub at: http://localhost:9900"
    echo "  Use './scripts/stop_stack.sh' to stop the stack"
fi
