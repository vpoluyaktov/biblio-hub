# BiblioHub

> Central hub for the Biblio application suite

BiblioHub provides unified deployment and a landing page for all Biblio services using Docker Swarm.

## Services

| Service | Description | Port |
|---------|-------------|------|
| **Biblio OPDS Server** | E-book library catalog via OPDS protocol | 9988 |
| **Biblio Audiobook Builder** | Convert e-books to audiobooks using TTS | 8080 |
| **Biblio TTS Server** | Text-to-speech engine (Silero models) | 5555 |

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Swarm mode enabled
- All service images built (see [Building Images](#building-images))

### Deploy

```bash
# Initialize Docker Swarm (if not already)
docker swarm init

# Deploy the stack
docker stack deploy -c stack.yaml biblio

# Check services status
docker stack services biblio

# View logs
docker service logs -f biblio_nginx-gateway
```

### Access

Once deployed, access the landing page at: **http://localhost**

Individual services:
- Landing Page: http://localhost/
- OPDS Server: http://localhost/opds/
- Audiobook Builder: http://localhost/audiobook/
- TTS Server: http://localhost/tts/

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
docker service scale biblio_biblio-tts-server-silero=5

# Update a service
docker service update --image biblio-opds-server:v2 biblio_biblio-opds-server

# Remove the stack
docker stack rm biblio

# View service logs
docker service logs biblio_biblio-opds-server
```

## Project Structure

```
biblio-hub/
├── README.md              # This file
├── Specification.md       # Detailed specification
├── stack.yaml             # Docker Swarm stack definition
├── nginx/
│   ├── nginx.conf         # Nginx reverse proxy config
│   └── html/
│       ├── index.html     # Landing page
│       └── style.css      # Landing page styles
└── config/
    └── .env.example       # Environment template
```

## Related Repositories

- [biblio-opds-server](https://github.com/vpoluyaktov/biblio-opds-server) - OPDS catalog server
- [biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts) - Audiobook converter
- [biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero) - TTS engine

## License

MIT
