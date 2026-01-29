#!/bin/bash
# BiblioHub Keycloak Entrypoint
# Processes the realm template with environment variables before starting Keycloak

set -e

# Default values if not set
export BIBLIO_HUB_HOSTNAME="${BIBLIO_HUB_HOSTNAME:-localhost}"
export BIBLIO_HUB_PORT="${BIBLIO_HUB_PORT:-9900}"

TEMPLATE_FILE="/opt/keycloak/data/import/biblio-realm.json.template"
OUTPUT_FILE="/opt/keycloak/data/import/biblio-realm.json"

# Process the template using sed (pure bash, no external dependencies)
if [ -f "$TEMPLATE_FILE" ]; then
    echo "Processing realm template with BIBLIO_HUB_HOSTNAME=$BIBLIO_HUB_HOSTNAME, BIBLIO_HUB_PORT=$BIBLIO_HUB_PORT"
    sed -e "s/\${BIBLIO_HUB_HOSTNAME}/$BIBLIO_HUB_HOSTNAME/g" \
        -e "s/\${BIBLIO_HUB_PORT}/$BIBLIO_HUB_PORT/g" \
        "$TEMPLATE_FILE" > "$OUTPUT_FILE"
    echo "Realm configuration generated at $OUTPUT_FILE"
else
    echo "Warning: Template file not found at $TEMPLATE_FILE"
fi

# Start Keycloak with all passed arguments
exec /opt/keycloak/bin/kc.sh "$@"
