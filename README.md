## Central orchestration hub for the Biblio application suite
https://demo.bibliohub.org/](https://demo.bibliohub.org/

---
**Landing Page**  - Central hub with links to all services
<img width="1272" height="872" alt="Screenshot 2026-03-22 at 22 54 53" src="https://github.com/user-attachments/assets/f728d46b-8b68-41ed-8747-58dd6fb5351d" />

---
**Biblio Catalog** - E-book library catalog with OPDS support
<img width="1728" height="842" alt="Screenshot 2026-03-22 at 23 00 50" src="https://github.com/user-attachments/assets/9c3cc736-8bb0-4047-bdc4-5256315144f1" />

---
**Audiobook Builder TTS** - Convert e-books to audiobooks using TTS 
<img width="1185" height="846" alt="Screenshot 2026-03-22 at 23 01 55" src="https://github.com/user-attachments/assets/be814b84-7f47-4797-9e1e-7260d6105a91" />
<img width="1189" height="858" alt="Screenshot 2026-03-22 at 23 01 43" src="https://github.com/user-attachments/assets/796dbf89-a616-447c-a09b-c72a702aa968" />

---
**Audiobook Builder IA** - Build audiobooks from Internet Archive content
<img width="1727" height="540" alt="Screenshot 2026-03-22 at 23 02 57" src="https://github.com/user-attachments/assets/5bd1631a-0275-4c2f-9606-bd01a991266f" />

---
**Stress Server Silero** - Russian stress marking for TTS
<img width="977" height="641" alt="Screenshot 2026-03-22 at 23 03 14" src="https://github.com/user-attachments/assets/d8184168-78b4-4c2a-b904-b5746f3e3c0a" />

---
**TTS Server OpenVoice** - Text-to-speech engine (MeloTTS)
<img width="989" height="665" alt="Screenshot 2026-03-22 at 23 03 25" src="https://github.com/user-attachments/assets/a449aa18-3b9c-4640-9749-1f3c30e8dfc9" />

---
**TTS Server Piper** - Text-to-speech engine (Piper models)
<img width="995" height="654" alt="Screenshot 2026-03-22 at 23 03 34" src="https://github.com/user-attachments/assets/b8c1208c-a83e-43e6-a512-c9f84150dc46" />

---
**Biblio Auth** - Authentication and user management
<img width="1234" height="480" alt="Screenshot 2026-03-22 at 23 03 51" src="https://github.com/user-attachments/assets/a585acfd-c0e5-411f-8f8e-013dcc4dcdea" />




BiblioHub provides unified deployment with path-based routing through a single nginx gateway, Biblio Auth authentication, and a landing page for all Biblio services using Docker Swarm.

**Live demo: [https://demo.bibliohub.org/](https://demo.bibliohub.org/)**

## Services

All services are accessible through a single port (9900) via path-based routing:

| Service | Description | URL Path |
|---------|-------------|----------|
| **Landing Page** | Central hub with links to all services | `/` |
| **Audiobook Builder TTS** | Convert e-books to audiobooks using TTS | `/abb-tts/` |
| **Audiobook Builder IA** | Build audiobooks from Internet Archive content | `/abb-ia/` |
| **Biblio Catalog** | E-book library catalog with OPDS support | `/catalog/` |
| **TTS Server Silero** | Text-to-speech engine (Silero models) | `/tts-silero/` |
| **TTS Server OpenVoice** | Text-to-speech engine (MeloTTS) | `/tts-openvoice/` |
| **TTS Server Piper** | Text-to-speech engine (Piper models) | `/tts-piper/` |
| **Stress Server Silero** | Russian stress marking for TTS | `/stress-silero/` |
| **Biblio Auth** | Authentication and user management | `/auth/` |

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Swarm mode enabled
- All Biblio repositories cloned as siblings (see [Related Repositories](#related-repositories))

### Deploy

```bash
cp .env.example .env
nano .env  # Set EBOOKS_PATH and other variables

./scripts/start_stack.sh

docker stack services bibliohub
```

### Access

Once deployed, access all services at `http://localhost:9900`:

| Service | URL |
|---------|-----|
| Landing Page | http://localhost:9900/ |
| Audiobook Builder TTS | http://localhost:9900/abb-tts/ |
| Audiobook Builder IA | http://localhost:9900/abb-ia/ |
| Biblio Catalog | http://localhost:9900/catalog/ |
| Biblio Auth Admin | http://localhost:9900/auth/admin |

## Building Images

All Biblio repositories must be cloned locally as siblings (see [Related Repositories](#related-repositories)).

```bash
./scripts/rebuild_stack.sh
```

This builds all service images (router, biblio-auth, abb-tts, abb-ia, tts-silero, tts-openvoice, tts-piper, stress-silero, catalog) from sibling repositories and pushes them with `dev-latest` tag.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
EBOOKS_PATH=/path/to/your/ebooks

BIBLIO_HUB_HOSTNAME=localhost
BIBLIO_HUB_PORT=9900

SILERO_MODELS=v3_en,v5_ru,v5_1_ru
TTS_SILERO_REPLICAS=3
OPENVOICE_LANGUAGES=EN,ES
TTS_OPENVOICE_REPLICAS=1
PIPER_MODELS=en_US-lessac-medium,en_GB-alan-medium
TTS_PIPER_REPLICAS=1

BIBLIO_AUTH_SECRET_KEY=  # Generate a random string for production
BIBLIO_AUTH_ADMIN_PASSWORD=admin
BIBLIO_AUTH_USER_PASSWORD=user
```

See `.env.example` for all available options.

### Data Directories

The stack uses bind mounts to `./data/` directory (created automatically):

| Directory | Purpose |
|-----------|---------|
| `data/abb_tts/db/` | Audiobook Builder TTS database |
| `data/abb_tts/temp/` | Working files and audiobooks |
| `data/abb_tts/logs/` | Log files |
| `data/tts_silero/models/` | Silero TTS model cache |
| `data/tts_openvoice/models/` | OpenVoice TTS model cache |
| `data/tts_piper/models/` | Piper TTS model cache |
| `data/opds/db/` | Biblio Catalog database |
| `data/biblio_auth/db/` | Biblio Auth SQLite database |

## Management

```bash
docker service scale bibliohub_tts-silero=5

./scripts/stop_stack.sh

./scripts/rebuild_stack.sh
./scripts/start_stack.sh

docker service logs bibliohub_abb-tts --tail 100 -f
```

## Project Structure

```
biblio-hub/
├── README.md              # This file
├── stack.yaml             # Docker Swarm stack definition
├── .env.example           # Environment template
├── scripts/
│   ├── start_stack.sh     # Start the stack
│   ├── stop_stack.sh      # Stop the stack
│   ├── rebuild_stack.sh   # Rebuild all Docker images
│   ├── start_stack.bat    # Windows start script
│   └── stop_stack.bat     # Windows stop script
└── data/                  # Persistent data (auto-created)
```

Gateway/router configuration (nginx.conf, landing page) is in the separate [biblio-router](https://github.com/vpoluyaktov/biblio-router) repository.

## Related Repositories

All repositories should be cloned as siblings:

```
biblio-suite/
├── biblio-hub/                      # This repo — orchestration and deployment
├── biblio-router/                   # Nginx gateway and landing page
├── biblio-auth/                     # Authentication service
├── biblio-audiobook-builder-tts/    # E-book to audiobook converter (TTS)
├── biblio-audiobook-builder-ia/     # Internet Archive audiobook builder
├── biblio-ebooks-catalog/           # E-book catalog with OPDS
├── biblio-ebook-parser/             # Shared e-book parsing library
├── biblio-tts-server-silero/        # Silero TTS engine
├── biblio-tts-server-openvoice/     # OpenVoice TTS engine
├── biblio-tts-server-piper/         # Piper TTS engine
└── biblio-stress-server-silero/     # Russian stress marking
```

| Repository | Description |
|------------|-------------|
| [biblio-hub](https://github.com/vpoluyaktov/biblio-hub) | This repository — orchestration and deployment |
| [biblio-router](https://github.com/vpoluyaktov/biblio-router) | Nginx gateway and landing page |
| [biblio-auth](https://github.com/vpoluyaktov/biblio-auth) | Authentication service (Go) |
| [biblio-audiobook-builder-tts](https://github.com/vpoluyaktov/biblio-audiobook-builder-tts) | E-book to audiobook converter (Go) |
| [biblio-audiobook-builder-ia](https://github.com/vpoluyaktov/biblio-audiobook-builder-ia) | Internet Archive audiobook builder (Go) |
| [biblio-ebooks-catalog](https://github.com/vpoluyaktov/biblio-ebooks-catalog) | E-book catalog with OPDS support (Go) |
| [biblio-ebook-parser](https://github.com/vpoluyaktov/biblio-ebook-parser) | Shared e-book parsing library (Go) |
| [biblio-tts-server-silero](https://github.com/vpoluyaktov/biblio-tts-server-silero) | Silero TTS engine (Python) |
| [biblio-tts-server-openvoice](https://github.com/vpoluyaktov/biblio-tts-server-openvoice) | OpenVoice TTS engine (Python) |
| [biblio-tts-server-piper](https://github.com/vpoluyaktov/biblio-tts-server-piper) | Piper TTS engine (Python) |
| [biblio-stress-server-silero](https://github.com/vpoluyaktov/biblio-stress-server-silero) | Russian stress marking (Python) |

## License

MIT
