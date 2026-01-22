# BiblioHub

> Central hub for the Biblio application suite

BiblioHub provides unified deployment and a landing page for all Biblio services using Docker Swarm.

## Services

| Service | Description | Port |
|---------|-------------|------|
| **Landing Page** | Central hub with links to all services | 9900 |
| **Biblio Audiobook Builder TTS** | Convert e-books to audiobooks using TTS | 9901 |
| **Biblio TTS Server Silero** | Text-to-speech engine (Silero models) | 9902 |
| **Biblio OPDS Server** | E-book library catalog via OPDS protocol | 9903 |

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Swarm mode enabled
- All service images built (see [Building Images](#building-images))

### Deploy

```bash
# Start the stack (creates directories and deploys)
./scripts/start_stack.sh

# Check services status
docker stack services bibliohub

# View logs
docker service logs -f bibliohub_nginx-gateway
```

### Access

Once deployed, access the services at:

| Service | URL |
|---------|-----|
| Landing Page | http://localhost:9900 |
| Audiobook Builder TTS | http://localhost:9901 |
| TTS Server Silero | http://localhost:9902 |
| OPDS Server | http://localhost:9903 |

The landing page provides links that open each service in a new browser tab.

## Building Images

Before deploying, build all service images:

```bash
# Build OPDS Server
cd ../biblio-opds-server
docker build -t biblio-opds-server:latest -f docker/Dockerfile .

# Build Audiobook Builder (requires Dockerfile - see note below)
cd ../biblio-audiobook-builder-tts
docker build -t biblio-audiobook-builder-tts:latest .

# Build TTS Server
cd ../biblio-tts-server-silero
docker build -t biblio-tts-server-silero:latest -f docker/Dockerfile .
```

## Configuration

### Environment Variables

Create a `.env` file or set these variables before deployment:

```bash
# Books library path (for OPDS server)
export BOOKS_LIBRARY_PATH=/path/to/your/books

# TTS Server configuration
export SILERO_MODELS=v3_en,v5_ru,v5_1_ru
export TTS_REPLICAS=3
```

### Volumes

The stack uses the following persistent volumes:

| Volume | Purpose |
|--------|---------|
| `opds-data` | OPDS server database |
| `audiobook-data` | Audiobook builder database |
| `audiobook-output` | Generated audiobook files |
| `tts-models` | Cached Silero TTS models |

## Management

```bash
# Scale TTS service
docker service scale bibliohub_tts-silero=5

# Update a service
docker service update --image biblio-opds-server:v2 bibliohub_opds-server

# Stop the stack
./scripts/stop_stack.sh

# Rebuild all images
./scripts/rebuild_stack.sh

# View service logs
docker service logs bibliohub_opds-server
```

## Project Structure

```
biblio-hub/
├── README.md              # This file
├── Specification.md       # Detailed specification
├── stack.yaml             # Docker Swarm stack definition
├── scripts/
│   ├── start_stack.sh     # Start the stack
│   ├── stop_stack.sh      # Stop the stack
│   └── rebuild_stack.sh   # Rebuild all Docker images
├── nginx/
│   ├── nginx.conf         # Nginx config for landing page
│   └── html/
│       ├── index.html     # Landing page
│       └── style.css      # Landing page styles
└── data/                  # Persistent data (created by start_stack.sh)
    ├── abb_tts/           # Audiobook Builder data
    ├── tts_silero/        # TTS models cache
    └── opds_server/       # OPDS database and books
```

## Related Repositories

- [biblio-opds-server](https://github.com/vpoluyaktov/biblio-opds-server) - OPDS catalog server
- [biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts) - Audiobook converter
- [biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero) - TTS engine

## License

MIT
