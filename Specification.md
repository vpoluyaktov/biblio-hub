# BiblioHub Specification

> Central hub for the Biblio application suite

## Overview

BiblioHub is the central orchestration and landing page for the Biblio application suite. It provides:

1. **Docker Swarm Stack** - Unified deployment of all Biblio services
2. **Landing Page** - Central web portal with links to all services
3. **Service Discovery** - Nginx reverse proxy for routing to services

## Biblio Application Suite

| Service | Description | Port | Repository |
|---------|-------------|------|------------|
| **Biblio OPDS Server** | OPDS catalog server for e-book libraries | 9988 | [biblio-opds-server](https://github.com/vpoluyaktov/biblio-opds-server) |
| **Biblio Audiobook Builder TTS** | Converts e-books to audiobooks using TTS | 8080 | [biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts) |
| **Biblio TTS Server (Silero)** | REST API for Silero TTS models | 5555 | [biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero) |

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Docker Swarm                          │
                    │                                                          │
    Internet        │   ┌─────────────┐                                       │
        │           │   │   Nginx     │                                       │
        │           │   │  (Gateway)  │                                       │
        ▼           │   │             │                                       │
    ┌───────┐       │   │  :80/:443   │                                       │
    │ Users │◄─────►│   └──────┬──────┘                                       │
    └───────┘       │          │                                              │
                    │          ▼                                              │
                    │   ┌──────────────────────────────────────────────┐      │
                    │   │              Internal Network                 │      │
                    │   │                                              │      │
                    │   │  ┌─────────────┐  ┌─────────────────────┐   │      │
                    │   │  │ OPDS Server │  │ Audiobook Builder   │   │      │
                    │   │  │   :9988     │  │       :8080         │   │      │
                    │   │  └─────────────┘  └──────────┬──────────┘   │      │
                    │   │                              │              │      │
                    │   │                              ▼              │      │
                    │   │                   ┌─────────────────────┐   │      │
                    │   │                   │  TTS Server Silero  │   │      │
                    │   │                   │  (5 replicas) :5555 │   │      │
                    │   │                   └─────────────────────┘   │      │
                    │   └──────────────────────────────────────────────┘      │
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
├── nginx/
│   ├── nginx.conf            # Nginx configuration
│   └── html/
│       ├── index.html        # Landing page
│       └── style.css         # Landing page styles
└── config/
    └── .env.example          # Environment variables template
```

## Docker Swarm Stack Configuration

### Services

#### 1. nginx-gateway
- **Image**: nginx:alpine
- **Ports**: 80 (HTTP), 443 (HTTPS future)
- **Role**: Reverse proxy and landing page server
- **Replicas**: 1

#### 2. biblio-opds-server
- **Image**: biblio-opds-server:latest
- **Internal Port**: 9988
- **External Path**: /opds
- **Volumes**: Database, book library
- **Replicas**: 1

#### 3. biblio-audiobook-builder-tts
- **Image**: biblio-audiobook-builder-tts:latest
- **Internal Port**: 8080
- **External Path**: /audiobook
- **Dependencies**: biblio-tts-server-silero
- **Replicas**: 1

#### 4. biblio-tts-server-silero
- **Image**: biblio-tts-server-silero:latest
- **Internal Port**: 5555
- **External Path**: /tts (optional, mainly internal)
- **Replicas**: 5 (for parallel TTS processing)

### Networks

- **biblio-frontend**: External-facing network for nginx
- **biblio-backend**: Internal network for service communication

### Volumes

- **opds-data**: OPDS server database
- **audiobook-data**: Audiobook builder database and output
- **tts-models**: Silero TTS model cache

## Environment Variables

| Variable | Service | Description | Default |
|----------|---------|-------------|---------|
| `OPDS_DATABASE_PATH` | opds-server | Path to SQLite database | /data/opds.db |
| `OPDS_SERVER_PORT` | opds-server | Server port | 9988 |
| `ABB_DATABASE_PATH` | audiobook-builder | Path to SQLite database | /data/abb.db |
| `ABB_SERVER_PORT` | audiobook-builder | Server port | 8080 |
| `ABB_TTS_SERVER_URL` | audiobook-builder | URL to TTS server | http://biblio-tts-server-silero:5555 |
| `SILERO_PORT` | tts-server | TTS server port | 5555 |
| `SILERO_DEVICE` | tts-server | PyTorch device (cpu/cuda) | cpu |
| `SILERO_SERVED_MODELS` | tts-server | Models to load | v3_en,v5_ru |

## Deployment

### Prerequisites

1. Docker Engine with Swarm mode enabled
2. All service images built and available
3. Required volumes/directories created

### Quick Start

```bash
# Initialize swarm (if not already)
docker swarm init

# Deploy the stack
docker stack deploy -c stack.yaml biblio

# Check services
docker stack services biblio

# View logs
docker service logs biblio_nginx-gateway
```

### Building Images

```bash
# Build OPDS Server
cd ../biblio-opds-server
docker build -t biblio-opds-server:latest -f docker/Dockerfile .

# Build Audiobook Builder
cd ../biblio-audiobook-builder-tts
docker build -t biblio-audiobook-builder-tts:latest -f Dockerfile .

# Build TTS Server
cd ../biblio-tts-server-silero
docker build -t biblio-tts-server-silero:latest -f docker/Dockerfile .
```

## Progress Tracking

| Date | Status | Notes |
|------|--------|-------|
| 2026-01-22 | Started | Created repository and specification |
| 2026-01-22 | Completed | Phase 1-3 complete: stack.yaml, nginx, landing page, README |
| | | |

---

*Last updated: 2026-01-22*
