# BiblioHub Specification

> Central hub for the Biblio application suite

## Overview

BiblioHub is the central orchestration and landing page for the Biblio application suite. It provides:

1. **Docker Swarm Stack** - Unified deployment of all Biblio services
2. **Landing Page** - Central web portal with links to all services
3. **Direct Port Access** - Each service exposed on its own port for maximum compatibility

## Biblio Application Suite

| Service | Description | Port | Repository |
|---------|-------------|------|------------|
| **Landing Page (nginx)** | Central hub with links to all services | 9900 | This repository |
| **Biblio Audiobook Builder TTS** | Converts e-books to audiobooks using TTS | 9901 | [biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts) |
| **Biblio TTS Server (Silero)** | REST API for Silero TTS models | 9902 | [biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero) |
| **Biblio OPDS Server** | OPDS catalog server for e-book libraries | 9903 | [biblio-opds-server](https://github.com/vpoluyaktov/biblio-opds-server) |

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Docker Swarm                          │
                    │                                                          │
    Internet        │   ┌─────────────┐   ┌─────────────────────┐             │
        │           │   │   Nginx     │   │ Audiobook Builder   │             │
        │           │   │  (Landing)  │   │     (ABB_TTS)       │             │
        ▼           │   │   :9900     │   │       :9901         │             │
    ┌───────┐       │   └─────────────┘   └──────────┬──────────┘             │
    │ Users │◄─────►│                                │                        │
    └───────┘       │   ┌─────────────┐              ▼                        │
                    │   │ OPDS Server │   ┌─────────────────────┐             │
                    │   │   :9903     │   │  TTS Server Silero  │             │
                    │   └─────────────┘   │  (3 replicas) :9902 │             │
                    │                     └─────────────────────┘             │
                    │                                                          │
                    │   All services exposed on dedicated ports               │
                    │   Landing page opens each service in new browser tab    │
                    └─────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Core Infrastructure ✅
- [x] Create biblio-hub repository
- [x] Create Specification.md
- [x] Create docker swarm stack.yaml
- [x] Create nginx configuration
- [x] Create landing page HTML/CSS

### Phase 2: Service Integration ✅
- [x] Add biblio-opds-server to stack
- [x] Add biblio-audiobook-builder-tts to stack
- [x] Add biblio-tts-server-silero to stack
- [x] Configure inter-service networking

### Phase 3: Documentation ✅
- [x] Create README.md with deployment instructions
- [x] Document environment variables
- [ ] Add troubleshooting guide

### Phase 4: Future Enhancements
- [ ] Add Traefik for automatic SSL/TLS
- [ ] Add monitoring (Prometheus/Grafana)
- [ ] Add centralized logging
- [ ] Add health check dashboard

## Project Structure

```
biblio-hub/
├── Specification.md          # This file
├── README.md                 # Deployment instructions
├── stack.yaml                # Docker Swarm stack definition
├── scripts/
│   ├── start_stack.sh        # Start the stack
│   ├── stop_stack.sh         # Stop the stack
│   └── rebuild_stack.sh      # Rebuild all Docker images
├── nginx/
│   ├── nginx.conf            # Nginx configuration (landing page only)
│   └── html/
│       ├── index.html        # Landing page
│       └── style.css         # Landing page styles
└── data/                     # Persistent data (created by start_stack.sh)
    ├── abb_tts/              # Audiobook Builder data
    ├── tts_silero/           # TTS models cache
    └── opds_server/          # OPDS database and books
```

## Docker Swarm Stack Configuration

### Services

#### 1. nginx-gateway
- **Image**: nginx:alpine
- **Port**: 9900 (external)
- **Role**: Landing page server with links to all services
- **Replicas**: 1

#### 2. abb-tts (Audiobook Builder)
- **Image**: biblio-audiobook-builder-tts:latest
- **Port**: 9901 (external)
- **Volumes**: Database, output, temp
- **Dependencies**: tts-silero, opds-server
- **Replicas**: 1

#### 3. tts-silero (TTS Server)
- **Image**: biblio-tts-server-silero:latest
- **Port**: 9902 (external)
- **Volumes**: TTS models cache
- **Replicas**: 3 (for parallel TTS processing)

#### 4. opds-server
- **Image**: biblio-opds-server:latest
- **Port**: 9903 (external)
- **Volumes**: Database, book library
- **Replicas**: 1

### Networks

- **bibliohub-frontend**: External-facing network (all services with exposed ports)
- **bibliohub-backend**: Internal network for service-to-service communication

### Volumes

- **opds-data**: OPDS server database
- **audiobook-data**: Audiobook builder database and output
- **tts-models**: Silero TTS model cache

## Environment Variables

| Variable | Service | Description | Default |
|----------|---------|-------------|---------|
| `OPDS_DATABASE_PATH` | opds-server | Path to SQLite database | /data/opds.db |
| `OPDS_SERVER_PORT` | opds-server | Server port | 9903 |
| `ABB_TTS_DATABASE_PATH` | abb-tts | Path to SQLite database | /app/data/audiobook-builder.db |
| `ABB_TTS_PORT` | abb-tts | Server port | 9901 |
| `ABB_TTS_SERVER_URL` | abb-tts | URL to TTS server | http://tts-silero:9902 |
| `ABB_TTS_OPDS_SERVER_URL` | abb-tts | URL to OPDS server | http://opds-server:9903 |
| `SILERO_PORT` | tts-silero | TTS server port | 9902 |
| `SILERO_DEVICE` | tts-silero | PyTorch device (cpu/cuda) | cpu |
| `SILERO_SERVED_MODELS` | tts-silero | Models to load | v3_en,v5_ru,v5_1_ru |
| `TTS_SILERO_REPLICAS` | tts-silero | Number of TTS replicas | 3 |

## Deployment

### Prerequisites

1. Docker Engine with Swarm mode enabled
2. All service images built and available
3. Required volumes/directories created

### Quick Start

```bash
# Start the stack (creates directories and deploys)
./scripts/start_stack.sh

# Check services
docker stack services bibliohub

# View logs
docker service logs bibliohub_nginx-gateway

# Stop the stack
./scripts/stop_stack.sh
```

### Building Images

```bash
# Rebuild all images using the provided script
./scripts/rebuild_stack.sh
```

Or build individually:

```bash
# Build Audiobook Builder TTS
cd ../biblio-audiobook-builder-tts
docker build -t biblio-audiobook-builder-tts:latest .

# Build TTS Server Silero
cd ../biblio-tts-server-silero
docker build -t biblio-tts-server-silero:latest -f docker/Dockerfile .

# Build OPDS Server
cd ../biblio-opds-server
docker build -t biblio-opds-server:latest -f docker/Dockerfile .
```

## Progress Tracking

| Date | Status | Notes |
|------|--------|-------|
| 2026-01-22 | Started | Created repository and specification |
| 2026-01-22 | Completed | Phase 1-3 complete: stack.yaml, nginx, landing page, README |
| | | |

---

*Last updated: 2026-01-22*
