# BiblioHub Keycloak - Custom build with /auth base path
# This Dockerfile builds Keycloak with --http-relative-path=/auth configured at build time

# Stage 1: Build Keycloak with custom base path
FROM quay.io/keycloak/keycloak:23.0 as builder

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

# Copy realm configuration for import
COPY biblio-realm.json /opt/keycloak/data/import/biblio-realm.json

# Set working directory
WORKDIR /opt/keycloak

# Expose port 8080
EXPOSE 8080

# Use optimized startup with realm import
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized", "--import-realm"]
