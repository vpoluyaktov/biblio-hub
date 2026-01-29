#!/bin/bash
# BiblioHub Keycloak Entrypoint
# Processes the realm template with environment variables before starting Keycloak

set -e

# Default values if not set
export BIBLIO_HUB_HOSTNAME="${BIBLIO_HUB_HOSTNAME:-localhost}"
export BIBLIO_HUB_PORT="${BIBLIO_HUB_PORT:-9900}"
export OPDS_OIDC_CLIENT_SECRET="${OPDS_OIDC_CLIENT_SECRET:-opds-server-secret-key-2026}"
export BIBLIO_HUB_ADMIN_PASSWORD="${BIBLIO_HUB_ADMIN_PASSWORD:-admin}"
export BIBLIO_HUB_USER_PASSWORD="${BIBLIO_HUB_USER_PASSWORD:-user}"
export BIBLIO_OPDS_USER_PASSWORD="${BIBLIO_OPDS_USER_PASSWORD:-opds}"

TEMPLATE_FILE="/opt/keycloak/data/import/biblio-realm-template.json"
OUTPUT_FILE="/opt/keycloak/data/import/biblio-realm.json"

# Process the template using sed (pure bash, no external dependencies)
if [ -f "$TEMPLATE_FILE" ]; then
    echo "Processing realm template with BIBLIO_HUB_HOSTNAME=$BIBLIO_HUB_HOSTNAME, BIBLIO_HUB_PORT=$BIBLIO_HUB_PORT"
    sed -e "s/\${BIBLIO_HUB_HOSTNAME}/$BIBLIO_HUB_HOSTNAME/g" \
        -e "s/\${BIBLIO_HUB_PORT}/$BIBLIO_HUB_PORT/g" \
        -e "s/\${OPDS_OIDC_CLIENT_SECRET}/$OPDS_OIDC_CLIENT_SECRET/g" \
        -e "s/\${BIBLIO_HUB_ADMIN_PASSWORD}/$BIBLIO_HUB_ADMIN_PASSWORD/g" \
        -e "s/\${BIBLIO_HUB_USER_PASSWORD}/$BIBLIO_HUB_USER_PASSWORD/g" \
        -e "s/\${BIBLIO_OPDS_USER_PASSWORD}/$BIBLIO_OPDS_USER_PASSWORD/g" \
        "$TEMPLATE_FILE" > "$OUTPUT_FILE"
    echo "Realm configuration generated at $OUTPUT_FILE"
else
    echo "Warning: Template file not found at $TEMPLATE_FILE"
fi

# Start Keycloak with all passed arguments
exec /opt/keycloak/bin/kc.sh "$@"
