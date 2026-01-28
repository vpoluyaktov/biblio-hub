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

#### ✅ OPDS Server (Go/chi) - Completed 2026-01-28

**Changes Made:**

1. **Backend Route Registration:**
   - Routes already registered with base path support via chi router
   - BasePath configured in `config.go` and used in `server.go`
   - Example: Routes mounted under `basePath` prefix

2. **Frontend JavaScript (app.js):**
   - Added `apiUrl()` helper function to prefix all API calls
   - Updated all `fetch()` calls to use `apiUrl()`
   - Updated all OPDS feed URLs to use base path

3. **HTML Template (index.html):**
   - Already injected `window.APP_BASE_PATH` for JavaScript access
   - Static assets already use `{{.BasePath}}` template variable

**Verification:**
- ✅ Backend routes support base path via chi router
- ✅ Frontend `apiUrl()` helper added
- ✅ All fetch calls updated
- ✅ OPDS feeds work with base path

#### ✅ TTS Silero Server (Python/FastAPI) - Completed 2026-01-28

**Changes Made:**

1. **Backend Configuration:**
   - `base_path` already configured in `config.py`
   - FastAPI app already uses `root_path=settings.base_path`
   - Routes automatically namespaced by FastAPI

2. **Frontend HTML (index.html):**
   - Added `BASE_PATH` constant and `apiUrl()` helper function
   - Updated all `fetch()` calls to use `apiUrl()`
   - API calls: `/api/languages`, `/api/models`, `/api/voices`, `/api/tts`

**Verification:**
- ✅ FastAPI `root_path` configured
- ✅ Frontend `apiUrl()` helper added
- ✅ All fetch calls updated

#### ✅ TTS OpenVoice Server (Python/FastAPI) - Completed 2026-01-28

**Changes Made:**

1. **Backend Configuration:**
   - `base_path` already configured in `config.py`
   - FastAPI app already uses `root_path=settings.base_path`
   - Routes automatically namespaced by FastAPI

2. **Frontend HTML (index.html):**
   - Added `BASE_PATH` constant and `apiUrl()` helper function
   - Updated all `fetch()` calls to use `apiUrl()`
   - API calls: `/api/languages`, `/api/voices`, `/api/tts`

**Verification:**
- ✅ FastAPI `root_path` configured
- ✅ Frontend `apiUrl()` helper added
- ✅ All fetch calls updated

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

## In Progress: Keycloak Authentication Integration (feature/keycloak-authentication)

### Problem Statement

Currently, all services in the BiblioHub suite are publicly accessible without authentication:
- No user management or access control
- Cannot restrict access to specific users or groups
- No audit trail of who accessed what
- Not suitable for multi-tenant or shared hosting environments
- Cannot implement role-based access control (RBAC)

### Solution: Centralized Authentication with Keycloak

Implement Keycloak as a centralized Identity and Access Management (IAM) solution that provides:
- **Single Sign-On (SSO)**: Users authenticate once and access all services
- **OAuth 2.0 / OpenID Connect**: Industry-standard authentication protocols
- **User Management**: Built-in user registration, password policies, MFA
- **Role-Based Access Control**: Define roles and permissions per service
- **Social Login**: Optional integration with Google, GitHub, etc.
- **Session Management**: Centralized session handling and logout

### Architecture Overview

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Docker Swarm                          │
                    │                                                          │
    Internet        │   ┌─────────────────────────────────────┐               │
        │           │   │   Nginx Gateway (:9900)             │               │
        │           │   │   - Landing page (/)                │               │
        │           │   │   - Auth check via auth_request     │               │
        │           │   │   - Proxy /auth/* → Keycloak:8080  │               │
        ▼           │   │   - Proxy /abb-tts/* → abb-tts:80  │               │
    ┌───────┐       │   │   - Proxy /opds/* → opds-server:80 │               │
    │ Users │◄─────►│   └─────────────────────────────────────┘               │
    └───────┘       │                      │                                  │
                    │          ┌───────────┼───────────────┐                  │
                    │          ▼           ▼               ▼                  │
                    │   ┌──────────┐ ┌──────────┐  ┌─────────────┐           │
                    │   │ Keycloak │ │ Services │  │  Services   │           │
                    │   │  :8080   │ │  :80     │  │   :80       │           │
                    │   │(internal)│ │(protected)│  │ (protected) │           │
                    │   └──────────┘ └──────────┘  └─────────────┘           │
                    │        │                                                │
                    │        ▼                                                │
                    │   ┌──────────┐                                          │
                    │   │ Postgres │  (Keycloak DB)                          │
                    │   │  :5432   │                                          │
                    │   └──────────┘                                          │
                    │                                                          │
                    └─────────────────────────────────────────────────────────┘
```

### Authentication Flow

1. **User accesses protected resource** (e.g., `/abb-tts/`)
2. **Nginx auth_request** checks authentication with Keycloak
3. **If not authenticated**: Redirect to Keycloak login page (`/auth/realms/biblio/protocol/openid-connect/auth`)
4. **User logs in** via Keycloak UI
5. **Keycloak issues tokens**: Access token, ID token, refresh token
6. **Nginx sets session cookie** and allows access to protected resource
7. **Subsequent requests**: Nginx validates session cookie, no redirect needed

### Pros

#### Security & Access Control
- ✅ **Industry-standard security**: OAuth 2.0 / OpenID Connect protocols
- ✅ **Centralized authentication**: Single point of control for all services
- ✅ **Role-based access control**: Fine-grained permissions per service
- ✅ **Multi-factor authentication**: Built-in support for TOTP, WebAuthn
- ✅ **Password policies**: Enforce complexity, expiration, history
- ✅ **Brute force protection**: Account lockout, CAPTCHA support

#### User Management
- ✅ **Self-service**: User registration, password reset, profile management
- ✅ **Social login**: Optional Google, GitHub, Facebook, etc.
- ✅ **User federation**: LDAP/Active Directory integration
- ✅ **Session management**: View active sessions, force logout
- ✅ **Audit logs**: Track authentication events and access

#### Developer Experience
- ✅ **Well-documented**: Extensive documentation and community support
- ✅ **Standard protocols**: OAuth 2.0, OpenID Connect, SAML 2.0
- ✅ **Client libraries**: Available for Go, Python, JavaScript, etc.
- ✅ **Admin UI**: Web-based configuration and management
- ✅ **REST API**: Programmatic configuration and user management

#### Scalability
- ✅ **Horizontal scaling**: Can run multiple Keycloak replicas
- ✅ **Session clustering**: Shared sessions across replicas
- ✅ **Database-backed**: Persistent user data and configuration
- ✅ **Caching**: Built-in caching for performance

### Cons

#### Complexity
- ❌ **Additional service**: Adds Keycloak + PostgreSQL to the stack
- ❌ **Learning curve**: OAuth 2.0 / OpenID Connect concepts
- ❌ **Configuration overhead**: Realm, clients, roles, mappers setup
- ❌ **Debugging complexity**: More moving parts, token validation, etc.

#### Resource Usage
- ❌ **Memory footprint**: Keycloak requires ~512MB-1GB RAM minimum
- ❌ **Database required**: PostgreSQL adds ~100-200MB RAM
- ❌ **Storage**: Database persistence, session storage
- ❌ **CPU overhead**: Token generation, validation, encryption

#### Operational Overhead
- ❌ **Backup/restore**: Need to backup Keycloak database
- ❌ **Updates/patches**: Keep Keycloak updated for security
- ❌ **Monitoring**: Additional service to monitor and maintain

#### User Experience
- ❌ **Extra login step**: Users must authenticate before accessing services
- ❌ **Session timeouts**: Users may need to re-authenticate periodically
- ❌ **Redirect flow**: Initial redirect to Keycloak login page
- ❌ **Cookie requirements**: Browsers must accept cookies

### Implementation Difficulty

**Overall Difficulty**: ⭐⭐⭐⭐ (Moderate to High)

#### Phase 1: Keycloak Setup (Easy) ⭐⭐
- Add Keycloak and PostgreSQL to `stack.yaml`
- Configure environment variables
- Create initial realm and admin user
- **Estimated effort**: 2-4 hours

#### Phase 2: Nginx Integration (Moderate) ⭐⭐⭐
- Configure `auth_request` directive in nginx
- Implement token validation endpoint
- Handle authentication redirects
- Set up session cookies
- **Estimated effort**: 4-8 hours

#### Phase 3: Service Integration (Moderate to High) ⭐⭐⭐⭐
- **Go services (ABB-TTS, OPDS)**: Add OAuth 2.0 middleware
  - Token validation
  - User context extraction
  - Role-based authorization
- **Python services (TTS Silero, TTS OpenVoice)**: Add OIDC middleware
  - FastAPI security dependencies
  - Token validation
- **Estimated effort**: 8-16 hours

#### Phase 4: Frontend Updates (Easy) ⭐⭐
- Add login/logout buttons
- Handle authentication redirects
- Display user information
- **Estimated effort**: 2-4 hours

#### Phase 5: Testing & Documentation (Moderate) ⭐⭐⭐
- Test authentication flows
- Test role-based access
- Update documentation
- Create user guides
- **Estimated effort**: 4-8 hours

**Total Estimated Effort**: 20-40 hours

### Potential Catches & Challenges

#### 1. WebSocket Authentication
**Challenge**: WebSocket connections don't support standard HTTP headers for authentication.

**Solutions**:
- Pass token as query parameter: `ws://host/api/ws?token=xxx`
- Use cookie-based authentication (already set by nginx)
- Implement token validation in WebSocket upgrade handler

**Recommendation**: Use cookie-based authentication (simplest for browser clients)

#### 2. API Client Authentication
**Challenge**: Non-browser clients (CLI tools, scripts) need to authenticate.

**Solutions**:
- Service accounts with client credentials flow
- API keys mapped to Keycloak users
- Direct token endpoint access for programmatic clients

**Recommendation**: Implement both service accounts and API key support

#### 3. Internal Service Communication
**Challenge**: Services communicate internally (ABB-TTS → TTS servers, OPDS).

**Solutions**:
- **Option A**: Bypass authentication for internal network traffic
- **Option B**: Use service accounts with client credentials
- **Option C**: Use mutual TLS for service-to-service auth

**Recommendation**: Option A (simplest) - internal services on backend network don't require auth

#### 4. Session Management
**Challenge**: Managing session timeouts and refresh tokens.

**Solutions**:
- Configure appropriate session timeouts in Keycloak
- Implement token refresh logic in frontend
- Use refresh tokens for long-lived sessions

**Recommendation**: 30-minute access token, 8-hour refresh token, 24-hour session

#### 5. OPDS Client Compatibility
**Challenge**: OPDS readers (Calibre, FBReader, etc.) may not support OAuth 2.0.

**Solutions**:
- Implement HTTP Basic Auth for OPDS endpoints
- Map Basic Auth credentials to Keycloak users
- Provide API keys for OPDS clients

**Recommendation**: Implement Basic Auth proxy for OPDS compatibility

#### 6. Database Persistence
**Challenge**: Keycloak database must be backed up and persistent.

**Solutions**:
- Use Docker volume for PostgreSQL data
- Implement regular backup strategy
- Document restore procedures

**Recommendation**: Add PostgreSQL volume to `stack.yaml`, document backup procedures

#### 7. Initial Setup Complexity
**Challenge**: First-time setup requires manual Keycloak configuration.

**Solutions**:
- Provide realm export/import JSON
- Create setup script for initial configuration
- Document step-by-step setup process

**Recommendation**: Provide pre-configured realm JSON and automated setup script

#### 8. SSL/TLS Requirements
**Challenge**: OAuth 2.0 typically requires HTTPS in production for external access.

**Solutions**:
- Internal Docker Swarm communication (backend network) does not require SSL/TLS
- Only nginx gateway needs SSL/TLS for external internet access
- Use Let's Encrypt with Traefik or Certbot for production
- HTTP is acceptable for development and internal-only deployments

**Recommendation**: SSL/TLS only needed at nginx gateway level, not between internal services

#### 9. Performance Impact
**Challenge**: Token validation adds latency to every request.

**Solutions**:
- Cache validated tokens in nginx
- Use short-lived tokens with refresh
- Optimize token validation endpoint

**Recommendation**: Implement nginx token caching with 5-minute TTL

#### 10. Migration Path
**Challenge**: Existing deployments have no authentication.

**Solutions**:
- Make authentication optional via environment variable
- Provide migration guide for existing users
- Support gradual rollout (some services protected, others open)

**Recommendation**: Add `AUTH_ENABLED=false` flag for backward compatibility

#### 11. OPDS Server Dual Authentication Mode
**Challenge**: OPDS server already has internal authentication (SQLite database with users, roles, sessions). Need to support both standalone deployment (internal auth) and BiblioHub deployment (Keycloak).

**Current OPDS Authentication Features**:
- SQLite-based user database with bcrypt password hashing
- Two roles: `admin` and `readonly`
- Session-based authentication (30-day sessions)
- HTTP Basic Auth support for OPDS readers (Calibre, FBReader, etc.)
- User management API (create, update, delete users)
- CLI tool for user creation
- Setup wizard for first-time configuration

**Solutions**:
- **Option A**: Authentication mode selection via environment variable
  - `AUTH_MODE=internal` (default) - Use internal SQLite database
  - `AUTH_MODE=keycloak` - Use Keycloak for authentication
  - Implement authentication adapter pattern
  
- **Option B**: Dual authentication with fallback
  - Try Keycloak first, fall back to internal database
  - Allows gradual migration
  - More complex to maintain
  
- **Option C**: Keycloak-only with user migration
  - Migrate existing users to Keycloak
  - Deprecate internal authentication
  - Simplest long-term solution

**Recommendation**: Option A (mode selection) for maximum flexibility

**Implementation Details**:
```go
type AuthProvider interface {
    Authenticate(username, password string) (*User, error)
    ValidateSession(sessionID string) (*User, error)
    CreateSession(userID int64) (*Session, error)
    // ... other auth methods
}

type InternalAuthProvider struct {
    db *db.DB
    // existing auth.Auth implementation
}

type KeycloakAuthProvider struct {
    keycloakURL string
    realm       string
    clientID    string
    // Keycloak client
}

// Factory function
func NewAuthProvider(mode string, config *Config) AuthProvider {
    switch mode {
    case "keycloak":
        return &KeycloakAuthProvider{...}
    default:
        return &InternalAuthProvider{...}
    }
}
```

**Benefits**:
- ✅ Standalone OPDS deployments continue using internal auth
- ✅ BiblioHub deployments can use centralized Keycloak
- ✅ No breaking changes for existing users
- ✅ Easy to test both modes
- ✅ Clear separation of concerns

**OPDS Client Basic Auth Compatibility (Keycloak Mode)**:

Most OPDS readers (Calibre, FBReader, Moon+ Reader, KOReader, etc.) only support HTTP Basic Auth - they cannot perform OAuth 2.0 redirects or handle token-based authentication. When `AUTH_MODE=keycloak`, we need a **Basic Auth to Keycloak bridge**.

**Solution**: Use Keycloak's **Resource Owner Password Credentials (ROPC)** grant to validate Basic Auth credentials directly against Keycloak's user database:

```go
// KeycloakAuthProvider - Basic Auth validation via ROPC grant
func (k *KeycloakAuthProvider) Authenticate(username, password string) (*User, error) {
    // Exchange username/password for token via Keycloak's token endpoint
    // POST /realms/{realm}/protocol/openid-connect/token
    resp, err := http.PostForm(
        k.keycloakURL+"/realms/"+k.realm+"/protocol/openid-connect/token",
        url.Values{
            "grant_type": {"password"},
            "client_id":  {k.clientID},
            "username":   {username},
            "password":   {password},
        })
    
    if err != nil || resp.StatusCode != 200 {
        return nil, ErrInvalidCredentials
    }
    
    // Parse access token, extract user info and roles from JWT claims
    var tokenResp struct {
        AccessToken string `json:"access_token"`
    }
    json.NewDecoder(resp.Body).Decode(&tokenResp)
    
    // Decode JWT to get user info (sub, preferred_username, roles)
    user := extractUserFromToken(tokenResp.AccessToken)
    return user, nil
}
```

**Authentication Flow by Client Type**:

| Auth Mode | Browser/Web UI | OPDS Readers (Calibre, etc.) |
|-----------|---------------|------------------------------|
| `internal` | Session cookie → SQLite | Basic Auth → SQLite |
| `keycloak` | Keycloak OAuth redirect | Basic Auth → Keycloak ROPC |

**Key Points**:
- OPDS readers continue using Basic Auth credentials as before
- Credentials are validated against Keycloak instead of SQLite
- Users are managed in Keycloak (single source of truth)
- Roles from Keycloak are mapped to OPDS roles (`admin`, `readonly`)
- No changes required on OPDS client side

**Keycloak Configuration for ROPC**:
- Enable "Direct Access Grants" on the OPDS client in Keycloak
- This allows the password grant type for Basic Auth validation
- Note: ROPC is considered less secure than authorization code flow, but necessary for legacy clients

**Applies to Other Services**:
- ABB-TTS currently has no authentication - only needs Keycloak mode
- TTS servers are internal-only - no authentication needed
- Same pattern can be applied if other services add standalone auth later

### Implementation Approach

#### Two-Tier Strategy

**Tier 1: Gateway-Level Authentication (Recommended First)**
- Nginx handles all authentication via `auth_request`
- Services remain unchanged (no code modifications)
- Simpler implementation, faster deployment
- Good for protecting entire application

**Tier 2: Service-Level Authentication (Optional Enhancement)**
- Each service validates tokens independently
- Enables fine-grained authorization
- Required for API clients and service-to-service auth
- More complex but more flexible

**Recommendation**: Start with Tier 1, add Tier 2 as needed

### Configuration Requirements

#### Keycloak Configuration
- **Realm**: `biblio`
- **Clients**:
  - `nginx-gateway` (confidential, for nginx auth_request)
  - `abb-tts` (public, for frontend)
  - `opds-server` (public, for frontend)
  - `tts-silero` (bearer-only, internal)
  - `tts-openvoice` (bearer-only, internal)
- **Roles**:
  - `user` (default, access to all services)
  - `admin` (administrative access)
  - Service-specific roles as needed

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTH_ENABLED` | Enable/disable authentication at gateway | `false` |
| `AUTH_MODE` | Authentication mode (internal/keycloak) | `internal` |
| `KEYCLOAK_URL` | Keycloak base URL | `http://keycloak:8080` |
| `KEYCLOAK_REALM` | Keycloak realm name | `biblio` |
| `KEYCLOAK_CLIENT_ID` | Client ID for service | (service-specific) |
| `KEYCLOAK_CLIENT_SECRET` | Client secret | (generated) |

### Stack Changes Required

#### New Services
- `keycloak`: Keycloak server (port 8080, internal)
- `keycloak-db`: PostgreSQL database (port 5432, internal)

#### Modified Services
- `nginx-gateway`: Add auth_request configuration
- All services: Add `AUTH_ENABLED` environment variable

#### New Volumes
- `keycloak-db-data`: PostgreSQL data persistence

### Testing Strategy

#### Manual Testing
- [ ] User registration and login
- [ ] Access protected services
- [ ] Logout and session termination
- [ ] Token refresh
- [ ] Role-based access control
- [ ] WebSocket authentication
- [ ] OPDS client authentication
- [ ] API client authentication

#### Automated Testing
- [ ] Integration tests for authentication flows
- [ ] Token validation tests
- [ ] Authorization tests
- [ ] Session management tests

### Documentation Requirements

- [ ] Setup guide for Keycloak
- [ ] User guide for authentication
- [ ] Developer guide for token validation
- [ ] API client authentication guide
- [ ] OPDS client configuration guide
- [ ] Troubleshooting guide
- [ ] Security best practices

### Migration Path

1. **Phase 1**: Deploy Keycloak alongside existing services (auth disabled)
2. **Phase 2**: Test authentication with `AUTH_ENABLED=true` on staging
3. **Phase 3**: Enable authentication on production with user notification
4. **Phase 4**: Migrate existing users (if any user data exists)
5. **Phase 5**: Remove `AUTH_ENABLED` flag after stable period

### Alternative Solutions Considered

#### 1. OAuth2 Proxy
- **Pros**: Simpler, lightweight, nginx-focused
- **Cons**: No user management UI, limited features
- **Verdict**: Good for simple use cases, but Keycloak offers more features

#### 2. Authelia
- **Pros**: Lightweight, Docker-native, good documentation
- **Cons**: Less mature, smaller community, fewer features
- **Verdict**: Good alternative, but Keycloak is more established

#### 3. Custom Authentication Service
- **Pros**: Full control, minimal dependencies
- **Cons**: High development effort, security risks, maintenance burden
- **Verdict**: Not recommended unless very specific requirements

#### 4. Basic HTTP Authentication
- **Pros**: Simple, built-in nginx support
- **Cons**: No user management, no SSO, credentials in every request
- **Verdict**: Too basic for multi-service suite

### Recommendation

**Proceed with Keycloak integration** using the two-tier approach:

1. **Start with Tier 1** (Gateway-level authentication)
   - Faster implementation
   - Protects all services immediately
   - No service code changes required
   - Good for initial rollout

2. **Add Tier 2 later** (Service-level authentication)
   - When fine-grained authorization is needed
   - For API client support
   - For service-to-service authentication

3. **Make authentication optional** via `AUTH_ENABLED` flag
   - Backward compatibility
   - Easier testing and development
   - Gradual migration path

4. **Provide comprehensive documentation**
   - Setup guides for different scenarios
   - User guides for authentication
   - Troubleshooting guides

### Implementation Steps

#### Phase 1: Infrastructure Setup ✅ COMPLETED
- [x] Create feature branch `feature/keycloak-authentication`
- [x] Add Keycloak and PostgreSQL to `stack.yaml`
- [x] Configure environment variables in `.env.example`
- [x] Create data volumes in `start_stack.sh`
- [x] Add nginx proxy configuration for `/auth/`
- [x] Create custom Keycloak Dockerfile with `/auth` base path
  - Multi-stage build using official Keycloak 23.0 image
  - Pre-configured with `--http-relative-path=/auth` at build time
  - No source code forking required
  - Added to `rebuild_stack.sh` build and push steps
- [x] Deploy and verify Keycloak is accessible
  - Custom Keycloak image running successfully (1/1 replicas)
  - PostgreSQL 16-alpine running (1/1 replicas)
  - Accessible via http://localhost:9900/auth/
  - Admin console at http://localhost:9900/auth/admin/
  - Default credentials: admin/admin
  - Base path `/auth` working correctly

#### Phase 2: Keycloak Configuration ✅ COMPLETED
- [x] Create comprehensive setup documentation (keycloak/SETUP.md)
  - Step-by-step guide for realm creation
  - Client configuration for all 5 services
  - Role definitions (user, admin)
  - Test user creation instructions
  - Session and token settings
- [x] Create pre-configured realm JSON (keycloak/biblio-realm.json)
  - Realm: biblio with all settings
  - 5 Clients: nginx-gateway, abb-tts, opds-server, tts-silero, tts-openvoice
  - 2 Roles: user, admin
  - 2 Test users: testadmin/admin123, testuser/user123
  - Session timeouts: 30min access, 8hr session
- [x] Update Dockerfile to include realm import
  - Realm JSON copied to /opt/keycloak/data/import/
  - --import-realm flag added to startup command
- [x] Import realm via CLI and verify
  - Realm 'biblio' successfully imported
  - All clients, roles, and users created
  - OpenID Connect endpoints accessible

#### Phase 3: Nginx Gateway Integration ⏳
- [ ] Implement auth_request endpoint
- [ ] Configure authentication redirects
- [ ] Set up session cookie handling
- [ ] Add login/logout endpoints
- [ ] Test authentication flow

#### Phase 4: Service Integration (Optional) ⏳
- [ ] Implement authentication provider interface pattern
- [ ] Add Keycloak auth provider for OPDS server
- [ ] Add `AUTH_MODE` environment variable support
- [ ] Add OAuth 2.0 middleware to ABB-TTS
- [ ] Implement token validation
- [ ] Add user context extraction
- [ ] Test both internal and Keycloak auth modes
- [ ] Test service-level authorization

#### Phase 5: Frontend Updates ⏳
- [ ] Add login/logout buttons to landing page
- [ ] Add admin-only "User Management" tile linking to Keycloak Admin Console
- [ ] Update service UIs with user info
- [ ] Handle authentication errors gracefully
- [ ] Test user experience

### Landing Page: Admin-Only User Management Tile

Add a "User Management" tile to the BiblioHub landing page that links to Keycloak's Admin Console, visible only to users with admin role.

**Tile Configuration**:
```html
<!-- User Management tile - visible to admins only -->
<div class="tile admin-only" id="user-management-tile" style="display: none;">
    <a href="/auth/admin/biblio/console/" target="_blank">
        <div class="tile-icon">👥</div>
        <h3>User Management</h3>
        <p>Manage users, groups, and roles</p>
    </a>
</div>
```

**JavaScript Role Check**:
```javascript
// Check user role and show admin tile if authorized
async function checkUserRole() {
    try {
        const response = await fetch('/auth/realms/biblio/protocol/openid-connect/userinfo');
        if (response.ok) {
            const userInfo = await response.json();
            const roles = userInfo.realm_access?.roles || [];
            
            if (roles.includes('admin') || roles.includes('realm-admin')) {
                document.getElementById('user-management-tile').style.display = 'block';
            }
        }
    } catch (error) {
        console.log('User not authenticated or error fetching user info');
    }
}

document.addEventListener('DOMContentLoaded', checkUserRole);
```

**Keycloak Admin Console URLs**:
| URL | Description |
|-----|-------------|
| `/auth/admin/` | Full Admin Console (all realms) |
| `/auth/admin/biblio/console/` | Biblio realm console only |
| `/auth/admin/biblio/console/#/biblio/users` | Direct link to user management |

**Security Layers** (Defense in Depth):

1. **Frontend (UX)**: Tile hidden for non-admins via JavaScript
2. **Keycloak (Authorization)**: Admin Console requires `realm-admin` or `admin` role
3. **Optional Nginx (Gateway)**: Can block `/auth/admin/*` for non-admin users

```nginx
# Optional: Block admin console at gateway level
location /auth/admin/ {
    # Check for admin role in session/token
    auth_request /auth/check-admin;
    auth_request_set $auth_status $upstream_status;
    
    proxy_pass http://keycloak:8080;
    # ... proxy headers
}
```

**Role Mapping**:
| Keycloak Role | Access Level |
|---------------|--------------|
| `realm-admin` | Full Keycloak Admin Console access |
| `admin` | BiblioHub admin (can be mapped to realm-admin) |
| `user` | Regular user (no admin console access) |

**Benefits**:
- ✅ Centralized user management via Keycloak UI
- ✅ No custom admin UI development needed
- ✅ Full-featured user/group/role management
- ✅ Audit logging built into Keycloak
- ✅ Self-service password reset for users
- ✅ MFA configuration per user

#### Phase 6: Documentation & Testing ⏳
- [ ] Write setup documentation
- [ ] Write user guides
- [ ] Create troubleshooting guide
- [ ] Perform integration testing
- [ ] Update README.md

#### Phase 7: Deployment & Migration ⏳
- [ ] Test on staging environment
- [ ] Create migration guide
- [ ] Deploy to production
- [ ] Monitor and fix issues
- [ ] Gather user feedback

---

*Last updated: 2026-01-28*
