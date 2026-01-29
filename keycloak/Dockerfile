# BiblioHub Keycloak - Custom build with /auth base path
# This Dockerfile builds Keycloak with --http-relative-path=/auth configured at build time

# Stage 1: Build Keycloak with custom base path
FROM quay.io/keycloak/keycloak:23.0 AS builder

# Set working directory
WORKDIR /opt/keycloak

# Build Keycloak with /auth base path
# This pre-configures Keycloak to run under /auth instead of root /
RUN /opt/keycloak/bin/kc.sh build \
    --http-relative-path=/auth \
    --db=postgres \
    --health-enabled=true \
    --metrics-enabled=true

# Stage 2: Create runtime image
FROM quay.io/keycloak/keycloak:23.0

# Copy the optimized build from builder stage
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Copy realm template and entrypoint script
COPY biblio-realm-template.json /opt/keycloak/data/import/biblio-realm-template.json
COPY docker-entrypoint.sh /opt/keycloak/docker-entrypoint.sh

# Switch to root to set permissions
USER root
RUN chmod +x /opt/keycloak/docker-entrypoint.sh && \
    chown -R keycloak:keycloak /opt/keycloak/data/import

# Switch back to keycloak user
USER keycloak

# Set working directory
WORKDIR /opt/keycloak

# Expose port 8080
EXPOSE 8080

# Use custom entrypoint that processes the template before starting Keycloak
ENTRYPOINT ["/opt/keycloak/docker-entrypoint.sh"]
CMD ["start", "--optimized", "--import-realm"]
