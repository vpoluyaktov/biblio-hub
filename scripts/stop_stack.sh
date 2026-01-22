#!/bin/bash
# BiblioHub - Stop the Docker Swarm stack
# This script removes the BiblioHub stack from Docker Swarm

set -e

STACK_NAME="bibliohub"

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
