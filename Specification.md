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
    ├── abb_tts/logs/         # Log files
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
  - `./data/abb_tts/logs:/logs` - Log files
- **Environment**:
  - `ABB_TTS_TEMP_DIR=/data` - Working directory for all files
  - `ABB_TTS_LOG_FILE=/logs/abb_tts.log` - Log file path
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

## In Progress: Path-Based Routing (feature/path-based-routing)

### Problem Statement

Currently, each service is exposed on its own port (9900-9904), which is not suitable for internet exposure:
- Multiple ports need to be opened in firewall
- No centralized authentication/authorization
- Difficult to manage SSL/TLS certificates for multiple ports
- Poor user experience with different port numbers

### Solution: Single-Port Gateway with Path-Based Routing

Implement a reverse proxy architecture where:
- **Single entry point**: All services accessible through port 9900
- **Path-based routing**: Services accessed via URL paths (e.g., `/abb-tts/`, `/opds/`, `/tts-silero/`)
- **Internal communication**: Services communicate internally using Docker network (no external ports)
- **Future authentication**: Gateway will handle authentication/authorization (to be implemented later)

### URL Structure

| Service | Current URL | New URL |
|---------|-------------|---------|
| Landing Page | `http://host:9900/` | `http://host:9900/` |
| Audiobook Builder | `http://host:9901/` | `http://host:9900/abb-tts/` |
| OPDS Server | `http://host:9903/` | `http://host:9900/opds/` |
| TTS Silero | `http://host:9902/` | `http://host:9900/tts-silero/` (internal only) |
| TTS OpenVoice | `http://host:9904/` | `http://host:9900/tts-openvoice/` (internal only) |

### Architecture Changes

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Docker Swarm                          │
                    │                                                          │
    Internet        │   ┌─────────────────────────────────────┐               │
        │           │   │   Nginx Gateway (:9900)             │               │
        │           │   │   - Landing page (/)                │               │
        │           │   │   - Proxy /abb-tts/* → abb-tts:80  │               │
        │           │   │   - Proxy /opds/* → opds-server:80 │               │
        ▼           │   │   - Proxy /tts-silero/* (internal) │               │
    ┌───────┐       │   │   - Proxy /tts-openvoice/* (int)   │               │
    │ Users │◄─────►│   └─────────────────────────────────────┘               │
    └───────┘       │                      │                                  │
                    │          ┌───────────┼───────────┐                      │
                    │          ▼           ▼           ▼                      │
                    │   ┌──────────┐ ┌──────────┐ ┌──────────┐               │
                    │   │ ABB-TTS  │ │   OPDS   │ │ TTS Svrs │               │
                    │   │  :80     │ │  :80     │ │  :80     │               │
                    │   │(internal)│ │(internal)│ │(internal)│               │
                    │   └──────────┘ └──────────┘ └──────────┘               │
                    │                                                          │
                    └─────────────────────────────────────────────────────────┘
```

### Implementation Steps

#### Phase 1: Nginx Gateway Configuration ✅
- [x] Create feature branch `feature/path-based-routing`
- [x] Update `nginx/nginx.conf` with path-based routing rules
- [x] Configure proxy headers (X-Forwarded-For, X-Real-IP, etc.)
- [x] Add location blocks for each service
- [x] Update landing page links to use new paths
- [x] Add WebSocket support with connection upgrade mapping
- [x] Add Keycloak proxy configuration (commented, ready for future use)

#### Phase 2: Audiobook Builder TTS (Go) ✅
- [x] Create feature branch `feature/path-based-routing`
- [x] Add `BASE_PATH` environment variable (default: `/`)
- [x] Update HTTP router to use base path prefix
- [x] Fix static asset paths (CSS, JS) to be relative or use base path
- [x] Update WebSocket connection URLs in frontend
- [x] Update API endpoint URLs in frontend
- [x] Committed and pushed to feature branch

#### Phase 3: OPDS Server (Go) ✅
- [x] Create feature branch `feature/path-based-routing`
- [x] Add `BASE_PATH` environment variable (default: `/`)
- [x] Update chi router to use base path prefix
- [x] Fix static asset paths (CSS, JS) to be relative or use base path
- [x] Update OPDS feed URLs to include base path
- [x] Update API endpoint URLs in frontend
- [x] Committed and pushed to feature branch

#### Phase 4: TTS Server Silero (Python/FastAPI) ✅
- [x] Create feature branch `feature/path-based-routing`
- [x] Add `BASE_PATH` environment variable (default: `/`)
- [x] Configure FastAPI `root_path` parameter
- [x] Mount static files properly
- [x] Committed and pushed to feature branch

#### Phase 5: TTS Server OpenVoice (Python/FastAPI) ✅
- [x] Create feature branch `feature/path-based-routing`
- [x] Add `BASE_PATH` environment variable (default: `/`)
- [x] Configure FastAPI `root_path` parameter
- [x] Static file serving already configured
- [x] Committed and pushed to feature branch

#### Phase 6: Docker Stack Configuration ✅
- [x] Update `stack.yaml`:
  - [x] Remove external port mappings for services (except nginx:9900)
  - [x] Add `BASE_PATH` environment variables for all services
  - [x] Services listen on internal port 80
  - [x] Update health check URLs to include base paths
  - [x] Update internal service URLs (TTS servers, OPDS)
- [x] Remove services from frontend network (only backend)
- [x] Committed and pushed to feature branch

#### Phase 7: Documentation & Testing ⏳
- [ ] Update README.md with new URL structure
- [ ] Update service-specific Specification.md files
- [ ] Test all services with path-based routing
- [ ] Test internal service-to-service communication
- [ ] Verify WebSocket connections work through proxy
- [ ] Test file downloads through proxy

---

## ✅ Fixed: Path-Based Routing Implementation (Completed 2026-01-28)

### Problem Description

After implementing path-based routing, static assets (CSS, JS) and API routes were not working correctly. The initial approach had services register routes without the base path prefix, expecting nginx to strip it. However, this created conflicts when multiple services had the same route paths (e.g., `/assets/`, `/api/*`).

### Architecture Decision: Base Path Preservation

**New Approach:** Services register routes **WITH** the base path prefix, and nginx **preserves** the full path when forwarding.

When nginx configuration has:
```nginx
location /abb-tts/ {
    proxy_pass http://abb-tts:80;  # NO trailing slash = preserve prefix
}
```

Request flow:
1. Browser → Nginx: `GET /abb-tts/assets/style.css`
2. Nginx → Backend: `GET /abb-tts/assets/style.css` (base path preserved!)
3. Backend serves at `/abb-tts/assets/style.css`

**Rationale:** This approach allows multiple services to coexist with the same route patterns (e.g., all services can have `/assets/`, `/api/*`) without conflicts, since each service's routes are namespaced by its base path.

### Solution Implemented

#### ✅ ABB-TTS Server (Go/http.ServeMux) - Completed 2026-01-28

**Changes Made:**

1. **Backend Route Registration (server.go):**
   - Routes now registered **WITH** base path prefix
   - Example: `/abb-tts/`, `/abb-tts/assets/`, `/abb-tts/api/providers`, etc.
   ```go
   basePath := s.cfg.BasePath
   mux.Handle(basePath+"/assets/", http.StripPrefix(basePath+"/assets", http.FileServer(http.FS(assetsSubFS))))
   mux.HandleFunc(basePath+"/api/providers", s.handleProviders)
   mux.HandleFunc(basePath+"/health", s.handleHealth)
   ```

2. **Frontend JavaScript (app.js):**
   - Added `apiUrl()` helper function to prefix all API calls
   - Updated all `fetch()` calls and WebSocket connections
   ```javascript
   function apiUrl(path) {
       const basePath = window.APP_BASE_PATH || '';
       return basePath + path;
   }
   // Usage: fetch(apiUrl('/api/providers'))
   ```

3. **HTML Template (index.html):**
   - Injected `window.APP_BASE_PATH` for JavaScript access
   ```html
   <script>
       window.APP_BASE_PATH = "{{.BasePath}}";
   </script>
   ```

4. **Health Check (stack.yaml):**
   - Updated Docker health check to use base path endpoint
   ```yaml
   healthcheck:
     test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/abb-tts/health"]
   ```

5. **Nginx Configuration (nginx.conf):**
   - Removed trailing slash from `proxy_pass` to preserve base path
   ```nginx
   location /abb-tts/ {
       proxy_pass http://abb-tts:80;  # No trailing slash
   }
   ```

**Verification:**
- ✅ HTML page loads at `http://localhost:9900/abb-tts/`
- ✅ Static assets load with correct Content-Type
- ✅ API routes work: `/abb-tts/api/providers`, `/abb-tts/api/jobs`, etc.
- ✅ WebSocket connections work at `/abb-tts/api/ws`
- ✅ Health check passes

#### 🔄 Other Services - TO BE UPDATED

**The following services must be updated using the same approach:**

1. **OPDS Server** (`biblio-opds-server`)
   - Update route registration to include `/opds` prefix
   - Add JavaScript `apiUrl()` helper
   - Update nginx config to preserve prefix
   - Update health check endpoint

2. **TTS Silero Server** (`biblio-tts-server-silero`)
   - Update route registration to include `/tts-silero` prefix
   - Add JavaScript `apiUrl()` helper (if applicable)
   - Update nginx config to preserve prefix
   - Update health check endpoint

3. **TTS OpenVoice Server** (`biblio-tts-server-openvoice`)
   - Update route registration to include `/tts-openvoice` prefix
   - Add JavaScript `apiUrl()` helper (if applicable)
   - Update nginx config to preserve prefix
   - Update health check endpoint

### Key Principles

**For Backend Services:**
1. Register all routes **WITH** the base path prefix
2. Nginx preserves the full path when forwarding
3. Example: Register `/abb-tts/assets/`, nginx forwards `/abb-tts/assets/style.css` → backend serves it
4. Each service is isolated in its own namespace

**For HTML Templates:**
1. Inject `BasePath` variable from config (e.g., `/abb-tts`)
2. Use in templates: `<link href="{{.BasePath}}/assets/style.css">`
3. Browser requests full path: `/abb-tts/assets/style.css`
4. Nginx preserves prefix and forwards: `/abb-tts/assets/style.css`
5. Backend serves from registered route: `/abb-tts/assets/`

**For JavaScript/Frontend:**
1. Inject `window.APP_BASE_PATH` in HTML template
2. Create helper function: `apiUrl(path)` that prefixes all API calls
3. Update all `fetch()`, `XMLHttpRequest`, and `WebSocket` calls to use helper
4. Example: `fetch(apiUrl('/api/providers'))` → `/abb-tts/api/providers`

**For Nginx Configuration:**
1. Remove trailing slash from `proxy_pass` URL
2. Example: `proxy_pass http://service:80;` (not `http://service:80/`)
3. This preserves the full request path including the base path prefix

**For Health Checks:**
1. Update health check endpoint to include base path
2. Example: `/abb-tts/health` instead of `/health`

**Critical:** BasePath is used for BOTH route registration AND URL generation. Services must be self-contained and work on their designated sub-path.

### Technical Details

**Nginx Proxy Configuration (Updated):**
```nginx
location /abb-tts/ {
    proxy_pass http://abb-tts:80;  # NO trailing slash - preserves base path
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Prefix /abb-tts;
    
    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
}
```

**Go Router (chi) with Base Path:**
```go
basePath := os.Getenv("BASE_PATH")
if basePath == "" {
    basePath = "/"
}
r := chi.NewRouter()
r.Route(basePath, func(r chi.Router) {
    r.Get("/", handler)
    r.Get("/api/jobs", handler)
})
```

**FastAPI with Base Path:**
```python
base_path = os.getenv("BASE_PATH", "")
app = FastAPI(root_path=base_path)
```

**Frontend Asset Paths:**
- Use relative paths: `./style.css` instead of `/style.css`
- Or use base path variable: `{{.BasePath}}/static/style.css`

### Environment Variables

| Service | Variable | Default | Example |
|---------|----------|---------|---------|
| ABB-TTS | `BASE_PATH` | `/` | `/abb-tts` |
| OPDS Server | `BASE_PATH` | `/` | `/opds` |
| TTS Silero | `BASE_PATH` | `/` | `/tts-silero` |
| TTS OpenVoice | `BASE_PATH` | `/` | `/tts-openvoice` |

### Testing Checklist

- [ ] Landing page loads at `http://host:9900/`
- [ ] ABB-TTS UI loads at `http://host:9900/abb-tts/`
- [ ] ABB-TTS WebSocket connects successfully
- [ ] ABB-TTS can upload and process books
- [ ] ABB-TTS can download completed audiobooks
- [ ] OPDS Server UI loads at `http://host:9900/opds/`
- [ ] OPDS feeds work at `http://host:9900/opds/opds/{lib_id}`
- [ ] OPDS Server can download books
- [ ] TTS Silero API accessible internally
- [ ] TTS OpenVoice API accessible internally
- [ ] ABB-TTS can communicate with TTS servers
- [ ] ABB-TTS can communicate with OPDS server
- [ ] All static assets (CSS, JS, images) load correctly
- [ ] No mixed content warnings
- [ ] No CORS errors

### Migration Path

1. Deploy new version with path-based routing
2. Keep old port-based access working temporarily (for testing)
3. Update documentation and notify users
4. After validation period, remove external port mappings
5. Only nginx gateway exposed to internet

---

*Last updated: 2026-01-27*
