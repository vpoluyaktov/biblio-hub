# BiblioHub Specification

> Central orchestration hub for the Biblio application suite

## Overview

BiblioHub is the central deployment and orchestration platform for the Biblio application suite. It provides a unified Docker Swarm stack that deploys all Biblio services with a landing page for easy access.

## Biblio Application Suite

| Service | Description | Port | Specification |
|---------|-------------|------|---------------|
| **Landing Page** | Central hub with links to all services | 9900 | This document |
| **Audiobook Builder TTS** | Converts e-books to audiobooks using TTS | 9901 | [Specification.md](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts/blob/main/Specification.md) |
| **TTS Server (Silero)** | REST API for Silero TTS models | 9902 | [Specification.md](https://github.com/vpoluyaktov/biblio-tts-server-silero/blob/main/Specification.md) |
| **OPDS Server** | OPDS catalog server for e-book libraries | 9903 | [Specification.md](https://github.com/vpoluyaktov/biblio-opds-server/blob/main/Specification.md) |
| **TTS Server (OpenVoice)** | REST API for MeloTTS models | 9904 | [Specification.md](https://github.com/vpoluyaktov/biblio-tts-server-openvoice/blob/main/Specification.md) |

### Component Repositories

- **biblio-hub** (this repo): [github.com/vpoluyaktov/biblio-hub](https://github.com/vpoluyaktov/biblio-hub)
- **biblio-audiobook-builder-tts**: [github.com/vpoluyaktov/biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts)
- **biblio-tts-server-silero**: [github.com/vpoluyaktov/biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero)
- **biblio-tts-server-openvoice**: [github.com/vpoluyaktov/biblio-tts-server-openvoice](https://github.com/vpoluyaktov/biblio-tts-server-openvoice)
- **biblio-opds-server**: [github.com/vpoluyaktov/biblio-opds-server](https://github.com/vpoluyaktov/biblio-opds-server)

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Docker Swarm                          │
                    │                                                          │
    Internet        │   ┌─────────────┐   ┌─────────────────────┐             │
        │           │   │   Nginx     │   │ Audiobook Builder   │             │
        │           │   │  (Landing)  │   │     (ABB_TTS)       │             │
        │           │   │   :9900     │   │       :9901         │             │
        ▼           │   └─────────────┘   └──────────┬──────────┘             │
    ┌───────┐       │                                │                        │
    │ Users │◄─────►│   ┌─────────────┐              ▼                        │
    └───────┘       │   │ OPDS Server │   ┌─────────────────────┐             │
                    │   │   :9903     │   │  TTS Server Silero  │             │
                    │   └─────────────┘   │ (N replicas) :9902  │             │
                    │                     └─────────────────────┘             │
                    │                     ┌─────────────────────┐             │
                    │                     │ TTS Server OpenVoice│             │
                    │                     │ (N replicas) :9904  │             │
                    │                     └─────────────────────┘             │
                    │                                                          │
                    └─────────────────────────────────────────────────────────┘
```

### Service Communication

- **ABB-TTS → TTS-Silero**: Internal Docker network (`http://tts-silero:9902`)
- **ABB-TTS → OPDS Server**: Internal Docker network (`http://opds-server:9903`)
- **Users → All Services**: Direct port access (9900-9903)

## Project Structure

```
biblio-hub/
├── Specification.md          # This file
├── README.md                 # Quick start guide
├── stack.yaml                # Docker Swarm stack definition
├── .env                      # Environment configuration (create from template)
├── config/
│   └── .env.example          # Environment template
├── scripts/
│   ├── start_stack.sh        # Deploy/update the stack
│   ├── stop_stack.sh         # Stop and remove the stack
│   └── rebuild_stack.sh      # Rebuild and push all Docker images
├── nginx/
│   ├── Dockerfile            # Nginx image with landing page
│   ├── nginx.conf            # Nginx configuration
│   └── html/
│       ├── index.html        # Landing page
│       └── style.css         # Landing page styles
└── data/                     # Persistent data (auto-created)
    ├── abb_tts/db/           # Audiobook Builder database
    ├── abb_tts/temp/         # Working directory (ebook downloads, chapter files, audiobooks)
    ├── tts_silero/models/    # Silero TTS model cache
    ├── tts_openvoice/models/ # OpenVoice TTS model cache
    └── opds/db/              # OPDS server database
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
   └── biblio-opds-server/
   ```

### Environment Configuration

Create a `.env` file in the repository root to customize deployment:

```bash
# Copy the template
cp config/.env.example .env

# Edit as needed
nano .env
```

**Available Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `SILERO_MODELS` | Comma-separated list of Silero models to load | `v3_en,v5_ru,v5_1_ru` |
| `TTS_SILERO_REPLICAS` | Number of Silero TTS server replicas | `3` |
| `OPENVOICE_LANGUAGES` | Comma-separated list of OpenVoice languages | `EN,ES` |
| `TTS_OPENVOICE_REPLICAS` | Number of OpenVoice TTS server replicas | `1` |
| `BOOKS_LIBRARY_PATH` | Path to e-book library for OPDS | `/data/books` |
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
1. Build all 4 Docker images from source
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

Or update a single service:

```bash
docker service update --image vpoluyaktov/bibliohub-audiobook-builder-tts:dev-latest --force bibliohub_abb-tts
```

### Viewing Logs

```bash
# All services
docker stack services bibliohub

# Specific service logs
docker service logs bibliohub_abb-tts --tail 100 -f
docker service logs bibliohub_tts-silero --tail 100 -f
docker service logs bibliohub_tts-openvoice --tail 100 -f
docker service logs bibliohub_opds-server --tail 100 -f
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

### nginx-gateway (Landing Page)
- **Image**: `vpoluyaktov/bibliohub-gateway:dev-latest`
- **Port**: 9900
- **Purpose**: Landing page with links to all services

### abb-tts (Audiobook Builder)
- **Image**: `vpoluyaktov/bibliohub-audiobook-builder-tts:dev-latest`
- **Port**: 9901
- **Volumes**: 
  - `./data/abb_tts/db:/db` - SQLite database
  - `./data/abb_tts/temp:/data` - Working directory (ebook downloads, chapter files, audiobooks)
- **Environment**:
  - `ABB_TTS_TEMP_DIR=/data` - Working directory for all files
- **Dependencies**: tts-silero, opds-server

### tts-silero (TTS Server Silero)
- **Image**: `vpoluyaktov/bibliohub-tts-server-silero:dev-latest`
- **Port**: 9902
- **Volumes**: `./data/tts_silero/models:/data/silero` - Model cache
- **Replicas**: Configurable via `TTS_SILERO_REPLICAS`
- **Models**: Configurable via `SILERO_MODELS`

### tts-openvoice (TTS Server OpenVoice)
- **Image**: `vpoluyaktov/bibliohub-tts-server-openvoice:dev-latest`
- **Port**: 9904
- **Volumes**: `./data/tts_openvoice/models:/data/openvoice` - Model cache
- **Replicas**: Configurable via `TTS_OPENVOICE_REPLICAS`
- **Languages**: Configurable via `OPENVOICE_LANGUAGES` (EN, ES, FR, ZH, JP, KR)

### opds-server (OPDS Catalog)
- **Image**: `vpoluyaktov/bibliohub-opds-server:dev-latest`
- **Port**: 9903
- **Volumes**:
  - `./data/opds/db:/db` - SQLite database
  - Book library mount (configurable)

## Networks

| Network | Purpose |
|---------|---------|
| `bibliohub-frontend` | External access, all services |
| `bibliohub-backend` | Internal service-to-service communication |

## Development Status

**Current State**: Fully operational

All core services are deployed and functional:
- ✅ Landing page with service links
- ✅ Audiobook Builder TTS with per-provider chunk size configuration
- ✅ TTS Server Silero with multiple models and scalable replicas
- ✅ TTS Server OpenVoice with MeloTTS multi-language support
- ✅ OPDS Server for e-book catalog

**Future Enhancements**:
- Traefik for automatic SSL/TLS
- Monitoring (Prometheus/Grafana)
- Health check dashboard

---

*Last updated: 2026-01-24*
