# BiblioHub

> Central orchestration hub for the Biblio application suite

BiblioHub provides unified deployment with path-based routing through a single nginx gateway, Keycloak authentication, and a landing page for all Biblio services using Docker Swarm.

## Services

All services are accessible through a single port (9900) via path-based routing:

| Service | Description | URL Path |
|---------|-------------|----------|
| **Landing Page** | Central hub with links to all services | `/` |
| **Audiobook Builder TTS** | Convert e-books to audiobooks using TTS | `/abb-tts/` |
| **Biblio Catalog** | E-book library catalog with OPDS support | `/catalog/` |
| **TTS Server Silero** | Text-to-speech engine (Silero models) | `/tts-silero/` |
| **TTS Server OpenVoice** | Text-to-speech engine (MeloTTS) | `/tts-openvoice/` |
| **Keycloak** | Identity and Access Management | `/auth/` |

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Swarm mode enabled
- All Biblio repositories cloned as siblings (see [Related Repositories](#related-repositories))

### Deploy

```bash
# Copy and configure environment
cp .env.example .env
nano .env  # Set EBOOKS_PATH and other variables

# Start the stack (creates directories and deploys)
./scripts/start_stack.sh

# Check services status
docker stack services bibliohub
```

### Access

Once deployed, access all services at `http://localhost:9900`:

| Service | URL |
|---------|-----|
| Landing Page | http://localhost:9900/ |
| Audiobook Builder TTS | http://localhost:9900/abb-tts/ |
| Biblio Catalog | http://localhost:9900/catalog/ |
| TTS Server Silero | http://localhost:9900/tts-silero/ |
| TTS Server OpenVoice | http://localhost:9900/tts-openvoice/ |
| Keycloak Admin | http://localhost:9900/auth/admin/ |

## Building Images

Build and push all service images to Docker Hub:

```bash
./scripts/rebuild_stack.sh
```

This builds all 6 images (gateway, keycloak, abb-tts, tts-silero, tts-openvoice, catalog) from sibling repositories and pushes them with `dev-latest` tag.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# E-book library path (required)
EBOOKS_PATH=/path/to/your/ebooks

# BiblioHub hostname and port
BIBLIO_HUB_HOSTNAME=localhost
BIBLIO_HUB_PORT=9900

# TTS Server configuration
SILERO_MODELS=v3_en,v5_ru,v5_1_ru
TTS_SILERO_REPLICAS=3
OPENVOICE_LANGUAGES=EN,ES
TTS_OPENVOICE_REPLICAS=1

# Authentication
AUTH_MODE=oidc  # or 'internal' for standalone Biblio Catalog
CATALOG_OIDC_CLIENT_SECRET=biblio-catalog-secret-key-2026
```

**Note**: The `CATALOG_OIDC_CLIENT_SECRET` must match between Keycloak and Biblio Catalog. If you change it, delete `data/keycloak/db/*` to force realm reimport.

See `.env.example` for all available options.

### Data Directories

The stack uses bind mounts to `./data/` directory (created automatically):

| Directory | Purpose |
|-----------|---------|
| `data/abb_tts/db/` | Audiobook Builder database |
| `data/abb_tts/temp/` | Working files and audiobooks |
| `data/abb_tts/logs/` | Log files |
| `data/tts_silero/models/` | Silero TTS model cache |
| `data/tts_openvoice/models/` | OpenVoice TTS model cache |
| `data/opds/db/` | Biblio Catalog database |
| `data/keycloak/db/` | Keycloak PostgreSQL database |

## Management

```bash
# Scale TTS service for parallel processing
docker service scale bibliohub_tts-silero=5

# Stop the stack (preserves data)
./scripts/stop_stack.sh

# Rebuild and redeploy after code changes
./scripts/rebuild_stack.sh
./scripts/start_stack.sh

# View service logs
docker service logs bibliohub_abb-tts --tail 100 -f
docker service logs bibliohub_biblio-catalog --tail 100 -f
```

## Project Structure

```
biblio-hub/
├── README.md              # This file
├── Specification.md       # Detailed specification
├── stack.yaml             # Docker Swarm stack definition
├── .env.example           # Environment template
├── scripts/
│   ├── start_stack.sh     # Start the stack
│   ├── stop_stack.sh      # Stop the stack
│   └── rebuild_stack.sh   # Rebuild all Docker images
├── nginx/
│   ├── Dockerfile         # Gateway image
│   ├── nginx.conf         # Path-based routing config
│   └── html/              # Landing page
├── keycloak/
│   ├── Dockerfile         # Custom Keycloak image
│   └── biblio-realm-template.json  # Pre-configured realm
└── data/                  # Persistent data (auto-created)
```

## Related Repositories

All repositories should be cloned as siblings:

```
~/git/
├── biblio-hub/                      # This repo
├── biblio-audiobook-builder-tts/    # Audiobook converter
├── biblio-ebooks-catalog/           # E-book catalog with OPDS
├── biblio-tts-server-silero/        # Silero TTS engine
└── biblio-tts-server-openvoice/     # OpenVoice TTS engine
```

- [biblio-hub](https://github.com/vpoluyaktov/biblio-hub) - This repository
- [biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts) - Audiobook converter
- [biblio-ebooks-catalog](https://github.com/vpoluyaktov/biblio-ebooks-catalog) - E-book catalog with OPDS
- [biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero) - Silero TTS engine
- [biblio-tts-server-openvoice](https://github.com/vpoluyaktov/biblio-tts-server-openvoice) - OpenVoice TTS engine

## License

MIT
