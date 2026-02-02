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
                    │          │           │                                  │
                    │          └─────┬─────┘                                  │
                    │                ▼                                        │
                    │         ┌─────────────┐                                │
                    │         │ Biblio Auth │                                │
                    │         │    :80      │                                │
                    │         └─────────────┘                                │
                    │                                                          │
                    └─────────────────────────────────────────────────────────┘
```

### Service Communication

- **ABB-TTS → TTS-Silero**: Internal Docker network (`http://tts-silero:80/tts-silero`)
- **ABB-TTS → Biblio Catalog**: Internal Docker network (`http://biblio-catalog:80/catalog`)
- **Biblio Catalog → Biblio Auth**: Internal Docker network for JWT authentication (`http://biblio-auth:80/auth`)
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
└── data/                     # Persistent data (auto-created)
    ├── abb_tts/db/           # Audiobook Builder database
    ├── abb_tts/temp/         # Working directory (ebook downloads, chapter files, audiobooks)
    ├── abb_tts/logs/         # Log files
    ├── tts_silero/models/    # Silero TTS model cache
    ├── tts_openvoice/models/ # OpenVoice TTS model cache
    ├── opds/db/              # Biblio Catalog database
    └── biblio_auth/db/       # Biblio Auth SQLite database
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
| `BIBLIO_AUTH_SECRET_KEY` | JWT secret key for Biblio Auth | (generated) |
| `BIBLIO_AUTH_ADMIN_PASSWORD` | Biblio Auth admin password | `admin` |
| `BIBLIO_AUTH_USER_PASSWORD` | Biblio Auth regular user password | `user` |
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
1. Build all 6 Docker images from source (gateway, biblio-auth, abb-tts, tts-silero, tts-openvoice, catalog)
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
docker service logs bibliohub_biblio-auth --tail 100 -f
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
- **Authentication**: Uses Biblio Auth for web UI, internal auth for OPDS Basic Auth

### biblio-auth (Authentication Service)
- **Image**: `vpoluyaktov/bibliohub-auth:dev-latest`
- **Path**: `/auth/`
- **Admin Console**: `/auth/admin`
- **Volumes**: `./data/biblio_auth/db:/db` - SQLite database
- **Features**: User management, JWT sessions, group-based authorization

## Networks

| Network | Purpose |
|---------|---------|
| `bibliohub-frontend` | External access (nginx-gateway, abb-tts) |
| `bibliohub-backend` | Internal service-to-service communication |

## Authentication

BiblioHub uses **Biblio Auth** for centralized authentication:

- **Default users** (created on first startup):
  - `admin` / `${BIBLIO_AUTH_ADMIN_PASSWORD}` - Admin group
  - `user` / `${BIBLIO_AUTH_USER_PASSWORD}` - User group

### Authentication Flow

**Web UI Authentication:**
1. User accesses a protected service (e.g., Biblio Catalog)
2. Service redirects to `/auth/login?returnUrl=<current_url>`
3. User logs in at Biblio Auth
4. Biblio Auth issues JWT token as `auth_token` cookie
5. User is redirected back to the original service
6. Service validates token via `/auth/api/validate`

**OPDS/E-reader Authentication:**
1. E-reader sends HTTP Basic Auth header
2. Service validates credentials via Biblio Auth `/auth/api/login`
3. User info stored in request context

### Integration Guide

For detailed integration patterns and code examples, see:
- [biblio-auth/INTEGRATION_GUIDE.md](https://github.com/vpoluyaktov/biblio-auth/blob/main/INTEGRATION_GUIDE.md)

## Development Status

**Current State**: Fully operational

All core services are deployed and functional:
- ✅ Landing page with service links and health status
- ✅ Path-based routing through single nginx gateway
- ✅ Audiobook Builder TTS with per-provider chunk size configuration
- ✅ TTS Server Silero with multiple models and scalable replicas
- ✅ TTS Server OpenVoice with MeloTTS multi-language support
- ✅ Biblio Catalog with OPDS support and Biblio Auth integration
- ✅ Biblio Auth with user management and JWT authentication

### Future Enhancements

- Traefik for automatic SSL/TLS
- Monitoring (Prometheus/Grafana)
- Health check dashboard

---

*Last updated: 2026-02-02*
