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
| **TTS Server (Piper)** | REST API for Piper TTS models | `/tts-piper/` | [Specification.md](https://github.com/vpoluyaktov/biblio-tts-server-piper/blob/main/Specification.md) |
| **Biblio Auth** | Authentication and User Management | `/auth/` | [Specification.md](https://github.com/vpoluyaktov/biblio-auth/blob/main/Specification.md) |
| **Stress Server (Silero)** | REST API for Silero Stress (Russian text stress marking) | `/stress-silero/` | [Specification.md](https://github.com/vpoluyaktov/biblio-stress-server-silero/blob/main/Specification.md) |

All services are accessible through a single port (9900) via path-based routing.

### Component Repositories

- **biblio-hub** (this repo): [github.com/vpoluyaktov/biblio-hub](https://github.com/vpoluyaktov/biblio-hub)
- **biblio-auth**: [github.com/vpoluyaktov/biblio-auth](https://github.com/vpoluyaktov/biblio-auth)
- **biblio-audiobook-builder-tts**: [github.com/vpoluyaktov/biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts)
- **biblio-tts-server-silero**: [github.com/vpoluyaktov/biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero)
- **biblio-tts-server-openvoice**: [github.com/vpoluyaktov/biblio-tts-server-openvoice](https://github.com/vpoluyaktov/biblio-tts-server-openvoice)
- **biblio-tts-server-piper**: [github.com/vpoluyaktov/biblio-tts-server-piper](https://github.com/vpoluyaktov/biblio-tts-server-piper)
- **biblio-ebooks-catalog**: [github.com/vpoluyaktov/biblio-ebooks-catalog](https://github.com/vpoluyaktov/biblio-ebooks-catalog)
- **biblio-stress-server-silero**: [github.com/vpoluyaktov/biblio-stress-server-silero](https://github.com/vpoluyaktov/biblio-stress-server-silero)

## Architecture (High Level)

BiblioHub runs as a Docker Swarm stack with one public entry point and internal service-to-service communication.

- **Public access**: single host/port via nginx gateway
- **Routing model**: path-based routing (`/abb-tts/`, `/catalog/`, `/auth/`, etc.)
- **Authentication**: centralized through Biblio Auth
- **Service runtime**: independently deployable/scalable services behind the gateway

### System Context Diagram

```mermaid
flowchart LR
    U[Users / Clients]

    subgraph HUB[BiblioHub (Docker Swarm)]
        G[Nginx Gateway + Landing Page\nSingle public endpoint]

        A[ABB-TTS\n/abb-tts/]
        C[Biblio Catalog\n/catalog/]
        S[TTS Server Silero\n/tts-silero/]
        O[TTS Server OpenVoice\n/tts-openvoice/]
        P[TTS Server Piper\n/tts-piper/]
        R[Stress Server Silero\n/stress-silero/]
        B[Biblio Auth\n/auth/]
    end

    U -->|HTTP(S)| G

    G --> A
    G --> C
    G --> S
    G --> O
    G --> P
    G --> R
    G --> B

    A --> S
    A --> O
    A --> P
    A --> R
    C --> B
```

## Project Structure (Key Parts)

```
biblio-hub/
├── Specification.md
├── README.md
├── stack.yaml
├── .env.example
├── scripts/            # stack lifecycle and rebuild scripts
├── nginx/              # gateway config + landing page
└── data/               # persistent runtime data
```

## Operations Summary

BiblioHub lifecycle is managed through repository scripts:

- `./scripts/start_stack.sh` - deploy/update stack
- `./scripts/stop_stack.sh` - stop stack (data preserved)
- `./scripts/rebuild_stack.sh` - rebuild and publish service images

For exact operational and troubleshooting commands, see `README.md` and script sources.

## Current State

**Platform status: Operational**

Implemented and running:

- ✅ Unified gateway and landing page
- ✅ Path-based access to all core services via one endpoint
- ✅ Audiobook Builder TTS
- ✅ TTS Server (Silero)
- ✅ TTS Server (OpenVoice)
- ✅ Biblio Catalog (with OPDS)
- ✅ Biblio Auth

In progress / planned adoption in stack flow:

- ⏳ Stress Server (Silero) integration as a standard production component
- ⏳ TTS Server (Piper) integration for expanded language and voice support

## Development Priorities

Near-term roadmap:

1. Production-grade ingress/TLS automation (e.g., Traefik)
2. Monitoring and observability (Prometheus/Grafana)
3. Central health/status dashboard for all services
4. Continued cross-service reliability and deployment automation improvements

## Contribution Guidance

- Keep this document high-level (vision, architecture, status, roadmap).
- Put implementation details in service-level `Specification.md` files or `README.md`.
- When status changes, update **Current State** and **Development Priorities** first.

---

*Last updated: 2026-02-14*
