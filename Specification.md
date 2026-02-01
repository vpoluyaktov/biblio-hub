# BiblioHub Specification

> Central orchestration hub for the Biblio application suite

## Overview

BiblioHub is the central deployment and orchestration platform for the Biblio application suite. It provides a unified Docker Swarm stack with path-based routing through a single nginx gateway, Biblio Auth authentication, and a landing page for easy access to all services.

## Biblio Application Suite

| Service | Description | URL Path | Specification |
|---------|-------------|----------|---------------|
| **Landing Page** | Central hub with links to all services | `/` | This document |
| **Audiobook Builder TTS** | Converts e-books to audiobooks using TTS | `/abb-tts/` | [Specification.md](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts/blob/main/Specification.md) |
| **TTS Server (Silero)** | REST API for Silero TTS models | `/tts-silero/` | [Specification.md](https://github.com/vpoluyaktov/biblio-tts-server-silero/blob/main/Specification.md) |
| **Biblio Catalog** | E-book library catalog with OPDS support | `/catalog/` | [Specification.md](https://github.com/vpoluyaktov/biblio-ebooks-catalog/blob/main/Specification.md) |
| **TTS Server (OpenVoice)** | REST API for MeloTTS models | `/tts-openvoice/` | [Specification.md](https://github.com/vpoluyaktov/biblio-tts-server-openvoice/blob/main/Specification.md) |
| **Biblio Auth** | Authentication and User Management | `/auth/` | [Specification.md](https://github.com/vpoluyaktov/biblio-auth/blob/main/Specification.md) |

All services are accessible through a single port (9900) via path-based routing.

### Component Repositories

- **biblio-hub** (this repo): [github.com/vpoluyaktov/biblio-hub](https://github.com/vpoluyaktov/biblio-hub)
- **biblio-auth**: [github.com/vpoluyaktov/biblio-auth](https://github.com/vpoluyaktov/biblio-auth)
- **biblio-audiobook-builder-tts**: [github.com/vpoluyaktov/biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts)
- **biblio-tts-server-silero**: [github.com/vpoluyaktov/biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero)
- **biblio-tts-server-openvoice**: [github.com/vpoluyaktov/biblio-tts-server-openvoice](https://github.com/vpoluyaktov/biblio-tts-server-openvoice)
- **biblio-ebooks-catalog**: [github.com/vpoluyaktov/biblio-ebooks-catalog](https://github.com/vpoluyaktov/biblio-ebooks-catalog)

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Docker Swarm                          │
                    │                                                          │
    Internet        │   ┌─────────────────────────────────────┐               │
        │           │   │   Nginx Gateway (:9900)             │               │
        │           │   │   - Landing page (/)                │               │
        │           │   │   - Proxy /abb-tts/* → abb-tts     │               │
        │           │   │   - Proxy /catalog/* → biblio-catalog│              │
        ▼           │   │   - Proxy /tts-silero/* → tts-silero│               │
    ┌───────┐       │   │   - Proxy /tts-openvoice/* → tts-ov │               │
    │ Users │◄─────►│   │   - Proxy /auth/* → biblio-auth    │               │
    └───────┘       │   └─────────────────────────────────────┘               │
                    │                      │                                  │
                    │          ┌───────────┼───────────────┐                  │
                    │          ▼           ▼               ▼                  │
                    │   ┌──────────┐ ┌──────────┐  ┌─────────────┐           │
                    │   │ ABB-TTS  │ │ Catalog  │  │ TTS Servers │           │
                    │   │  :80     │ │  :80     │  │   :80       │           │
                    │   └──────────┘ └──────────┘  └─────────────┘           │
                    │          │                                              │
                    │          ▼                                              │
                    │   ┌──────────┐  ┌──────────┐                           │
                    │   │ Keycloak │──│ Postgres │                           │
                    │   │  :8080   │  │  :5432   │                           │
                    │   └──────────┘  └──────────┘                           │
                    │                                                          │
                    └─────────────────────────────────────────────────────────┘
```

### Service Communication

- **ABB-TTS → TTS-Silero**: Internal Docker network (`http://tts-silero:80/tts-silero`)
- **ABB-TTS → Biblio Catalog**: Internal Docker network (`http://biblio-catalog:80/catalog`)
- **Biblio Catalog → Keycloak**: Internal Docker network for OIDC authentication
- **Users → All Services**: Single port access (9900) via path-based routing

## Project Structure

```
biblio-hub/
├── Specification.md          # This file
├── README.md                 # Quick start guide
├── stack.yaml                # Docker Swarm stack definition
├── .env                      # Environment configuration (create from template)
├── .env.example              # Environment template
├── scripts/
│   ├── start_stack.sh        # Deploy/update the stack
│   ├── stop_stack.sh         # Stop and remove the stack
│   ├── rebuild_stack.sh      # Rebuild and push all Docker images
│   ├── start_stack.bat       # Windows: Deploy/update the stack
│   └── stop_stack.bat        # Windows: Stop and remove the stack
├── nginx/
│   ├── Dockerfile            # Nginx image with landing page
│   ├── nginx.conf            # Nginx configuration with path-based routing
│   └── html/
│       ├── index.html        # Landing page
│       └── style.css         # Landing page styles
├── keycloak/
│   ├── Dockerfile            # Custom Keycloak image with /auth base path
│   ├── docker-entrypoint.sh  # Entrypoint for realm template processing
│   ├── biblio-realm-template.json  # Pre-configured realm template
│   ├── README.md             # Keycloak overview
│   ├── SETUP.md              # Manual setup guide
│   └── SERVICE_INTEGRATION.md # Service integration patterns
└── data/                     # Persistent data (auto-created)
    ├── abb_tts/db/           # Audiobook Builder database
    ├── abb_tts/temp/         # Working directory (ebook downloads, chapter files, audiobooks)
    ├── abb_tts/logs/         # Log files
    ├── tts_silero/models/    # Silero TTS model cache
    ├── tts_openvoice/models/ # OpenVoice TTS model cache
    ├── opds/db/              # Biblio Catalog database
    └── keycloak/db/          # Keycloak PostgreSQL database
```

## Operations

### Prerequisites

1. Docker Engine with Swarm mode enabled
2. Docker Hub account (for pushing images)
3. All Biblio repositories cloned as siblings:
   ```
   ~/git/
   ├── biblio-hub/
   ├── biblio-audiobook-builder-tts/
   ├── biblio-tts-server-silero/
   ├── biblio-tts-server-openvoice/
   └── biblio-ebooks-catalog/
   ```

### Environment Configuration

Create a `.env` file in the repository root to customize deployment:

```bash
# Copy the template
cp .env.example .env

# Edit as needed
nano .env
```

**Available Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `BIBLIO_HUB_HOSTNAME` | Hostname where BiblioHub is accessible | `localhost` |
| `BIBLIO_HUB_PORT` | Port where BiblioHub is accessible | `9900` |
| `EBOOKS_PATH` | Path to e-book library for Biblio Catalog | `/data/EBooks` |
| `SILERO_MODELS` | Comma-separated list of Silero models to load | `v3_en,v5_ru,v5_1_ru` |
| `TTS_SILERO_REPLICAS` | Number of Silero TTS server replicas | `3` |
| `OPENVOICE_LANGUAGES` | Comma-separated list of OpenVoice languages | `EN,ES` |
| `TTS_OPENVOICE_REPLICAS` | Number of OpenVoice TTS server replicas | `1` |
| `AUTH_MODE` | Authentication mode for Biblio Catalog (`internal`/`oidc`) | `oidc` |
| `CATALOG_OIDC_CLIENT_SECRET` | OIDC client secret for Biblio Catalog | (generated) |
| `KEYCLOAK_ADMIN_USER` | Keycloak admin username | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | `admin` |
| `BIBLIO_HUB_ADMIN_PASSWORD` | Hub admin user password | `hub_admin` |
| `BIBLIO_HUB_USER_PASSWORD` | Hub regular user password | `hub_user` |
| `BIBLIO_OPDS_USER_PASSWORD` | OPDS user password (Basic Auth) | `opds_user` |
| `TZ` | Timezone | `UTC` |

### Starting the Stack

```bash
./scripts/start_stack.sh
```

This will:
1. Load environment variables from `.env` (if exists)
2. Initialize Docker Swarm (if not active)
3. Create data directories
4. Deploy the stack with `--resolve-image always` (pulls latest images)
5. Display service status until all services are ready

### Stopping the Stack

```bash
./scripts/stop_stack.sh
```

This removes all services and networks but **preserves data volumes**.

### Rebuilding Images

```bash
./scripts/rebuild_stack.sh
```

This will:
1. Build all 6 Docker images from source (gateway, keycloak, abb-tts, tts-silero, tts-openvoice, catalog)
2. Push them to Docker Hub with `dev-latest` tag
3. Images are built from sibling repositories

### Updating a Running Stack

After code changes:

```bash
# Rebuild and push images
./scripts/rebuild_stack.sh

# Redeploy (pulls new images automatically)
./scripts/start_stack.sh
```

### Viewing Logs

```bash
# All services
docker stack services bibliohub

# Specific service logs
docker service logs bibliohub_abb-tts --tail 100 -f
docker service logs bibliohub_tts-silero --tail 100 -f
docker service logs bibliohub_tts-openvoice --tail 100 -f
docker service logs bibliohub_biblio-catalog --tail 100 -f
docker service logs bibliohub_keycloak --tail 100 -f
```

### Scaling Services

```bash
# Scale TTS replicas (for more parallel processing)
docker service scale bibliohub_tts-silero=5

# Or set in .env and redeploy
echo "TTS_SILERO_REPLICAS=5" >> .env
./scripts/start_stack.sh
```

## Service Details

### nginx-gateway (Landing Page & Reverse Proxy)
- **Image**: `vpoluyaktov/bibliohub-gateway:dev-latest`
- **Port**: 9900 (external)
- **Purpose**: Landing page, path-based routing to all services

### abb-tts (Audiobook Builder)
- **Image**: `vpoluyaktov/bibliohub-audiobook-builder-tts:dev-latest`
- **Path**: `/abb-tts/`
- **Volumes**: 
  - `./data/abb_tts/db:/db` - SQLite database
  - `./data/abb_tts/temp:/data` - Working directory
  - `./data/abb_tts/logs:/logs` - Log files
- **Dependencies**: tts-silero, biblio-catalog

### tts-silero (TTS Server Silero)
- **Image**: `vpoluyaktov/bibliohub-tts-server-silero:dev-latest`
- **Path**: `/tts-silero/`
- **Volumes**: `./data/tts_silero/models:/data/silero` - Model cache
- **Replicas**: Configurable via `TTS_SILERO_REPLICAS`
- **Models**: Configurable via `SILERO_MODELS`

### tts-openvoice (TTS Server OpenVoice)
- **Image**: `vpoluyaktov/bibliohub-tts-server-openvoice:dev-latest`
- **Path**: `/tts-openvoice/`
- **Volumes**: `./data/tts_openvoice/models:/data/openvoice` - Model cache
- **Replicas**: Configurable via `TTS_OPENVOICE_REPLICAS`
- **Languages**: Configurable via `OPENVOICE_LANGUAGES` (EN, ES, FR, ZH, JP, KR)

### biblio-catalog (E-book Catalog with OPDS)
- **Image**: `vpoluyaktov/bibliohub-catalog:dev-latest`
- **Path**: `/catalog/`
- **Volumes**:
  - `./data/opds/db:/db` - SQLite database
  - `${EBOOKS_PATH}:/books:ro` - E-book library (read-only)
- **Authentication**: Supports both internal auth and OIDC (Keycloak)

### keycloak (Identity and Access Management)
- **Image**: `vpoluyaktov/bibliohub-keycloak:dev-latest`
- **Path**: `/auth/`
- **Admin Console**: `/auth/admin/`
- **Volumes**: `./data/keycloak/db` - PostgreSQL data (via keycloak-db service)
- **Pre-configured**: Biblio realm with clients, roles, and test users

### keycloak-db (PostgreSQL)
- **Image**: `postgres:16-alpine`
- **Purpose**: Keycloak database
- **Volumes**: `./data/keycloak/db:/var/lib/postgresql/data`

## Networks

| Network | Purpose |
|---------|---------|
| `bibliohub-frontend` | External access (nginx-gateway, abb-tts) |
| `bibliohub-backend` | Internal service-to-service communication |

## Authentication

BiblioHub uses Keycloak for centralized authentication:

- **Realm**: `biblio`
- **Pre-configured users**:
  - `hub_admin` / `${BIBLIO_HUB_ADMIN_PASSWORD}` - Admin role
  - `hub_user` / `${BIBLIO_HUB_USER_PASSWORD}` - User role
  - `opds_user` / `${BIBLIO_OPDS_USER_PASSWORD}` - OPDS Basic Auth access

### Authentication Modes

**Biblio Catalog** supports two authentication modes via `AUTH_MODE`:
- `oidc` (default in swarm): Uses Keycloak for authentication
- `internal`: Uses built-in SQLite user database (standalone deployment)

**OPDS Clients** (Calibre, FBReader, etc.) use HTTP Basic Auth, which is validated against Keycloak via Resource Owner Password Credentials (ROPC) grant.

### OIDC Client Secret Configuration

The `CATALOG_OIDC_CLIENT_SECRET` must match between Keycloak and Biblio Catalog:

1. **Keycloak side**: The secret is defined in `keycloak/biblio-realm-template.json` and processed at container startup by `docker-entrypoint.sh`. If the env var is not set, it defaults to `biblio-catalog-secret-key-2026`.

2. **Biblio Catalog side**: The secret is passed via `stack.yaml` from the `.env` file's `CATALOG_OIDC_CLIENT_SECRET` variable.

**Important**: Both sides must use the same secret value. If you change the secret:
- Update `.env` with the new `CATALOG_OIDC_CLIENT_SECRET` value
- Delete `data/keycloak/db/*` to force realm reimport with new secret
- Restart the stack with `./scripts/start_stack.sh`

The Keycloak realm is only imported on first startup when the database is empty. Subsequent restarts use the existing database configuration.

For detailed Keycloak documentation, see:
- `keycloak/README.md` - Admin console guide (login, add users, assign roles)
- `keycloak/SERVICE_INTEGRATION.md` - Integration patterns for developers

## Development Status

**Current State**: Fully operational

All core services are deployed and functional:
- ✅ Landing page with service links and health status
- ✅ Path-based routing through single nginx gateway
- ✅ Audiobook Builder TTS with per-provider chunk size configuration
- ✅ TTS Server Silero with multiple models and scalable replicas
- ✅ TTS Server OpenVoice with MeloTTS multi-language support
- ✅ Biblio Catalog with OPDS support and OIDC authentication
- ✅ Keycloak authentication with pre-configured realm

**Future Enhancements**:
- Traefik for automatic SSL/TLS
- Monitoring (Prometheus/Grafana)
- Health check dashboard
- **Simplified User Management UI**: The default Keycloak admin console is too sophisticated for BiblioHub end users. A custom, simplified user management interface should be built using Keycloak's REST Admin API (`/admin/realms/{realm}/users`). This would provide a friendly UI for common operations (list users, create/delete users, reset passwords, assign roles) while hiding Keycloak's complexity. The API supports all CRUD operations and requires admin access tokens for authentication.

---

*Last updated: 2026-01-29*
