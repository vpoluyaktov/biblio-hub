# BiblioHub Keycloak Configuration

This directory contains the custom Keycloak build and configuration files for BiblioHub authentication.

## Files

- **Dockerfile** - Custom Keycloak image with `/auth` base path
- **SETUP.md** - Step-by-step guide for configuring Keycloak
- **biblio-realm.json** - Exported realm configuration (created after setup)

## Quick Start

### 1. Build Custom Keycloak Image

The custom image is built automatically by `scripts/rebuild_stack.sh`, or manually:

```bash
docker build -t vpoluyaktov/bibliohub-keycloak:dev-latest .
docker push vpoluyaktov/bibliohub-keycloak:dev-latest
```

### 2. Deploy Stack

```bash
cd /home/ubuntu/git/biblio-hub
./scripts/start_stack.sh
```

### 3. Configure Keycloak

Follow the detailed instructions in [SETUP.md](./SETUP.md) to:
- Create the 'biblio' realm
- Configure session and token settings
- Create clients for each service
- Define roles (user, admin)
- Create test users
- Export realm configuration

### 4. Access Points

- **Keycloak Welcome**: http://localhost:9900/auth/
- **Admin Console**: http://localhost:9900/auth/admin/
- **Default Credentials**: admin/admin

## Realm Configuration

### Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| nginx-gateway | Confidential | Nginx auth_request integration |
| abb-tts | Public | Audiobook Builder frontend |
| opds-server | Public | OPDS Server frontend |
| tts-silero | Bearer-only | Internal TTS service |
| tts-openvoice | Bearer-only | Internal TTS service |

### Roles

| Role | Description |
|------|-------------|
| user | Regular user - access to all services |
| admin | Administrator - full access + user management |

### Test Users

| Username | Password | Roles | Purpose |
|----------|----------|-------|---------|
| testadmin | admin123 | admin, user | Testing admin features |
| testuser | user123 | user | Testing regular user access |

## Session Configuration

- **Access Token**: 30 minutes
- **SSO Session Idle**: 30 minutes
- **SSO Session Max**: 8 hours
- **Refresh Token**: 8 hours
- **Offline Session**: 30 days

## Maintenance

### Updating Keycloak Version

Edit `Dockerfile` and change the version:
```dockerfile
FROM quay.io/keycloak/keycloak:24.0 as builder
```

Then rebuild:
```bash
./scripts/rebuild_stack.sh
```

### Backing Up Realm Configuration

1. Login to Admin Console
2. Navigate to **Realm settings** → **Action** → **Partial export**
3. Export and save to `biblio-realm.json`
4. Commit to repository

### Importing Realm Configuration

The `biblio-realm.json` file is included in the Docker image at `/opt/keycloak/data/import/`.

**Option 1: Import via Admin Console (Recommended)**
1. Login to Admin Console: http://localhost:9900/auth/admin/
2. Click **Master** dropdown → **Create Realm**
3. Click **Browse** and select the `biblio-realm.json` file from your local copy
4. Click **Create**

**Option 2: Import via CLI (Inside Container)**
```bash
# Get container ID
CONTAINER_ID=$(docker ps -q -f name=bibliohub_keycloak | head -1)

# Import realm using Keycloak CLI
docker exec $CONTAINER_ID /opt/keycloak/bin/kc.sh import \
  --file /opt/keycloak/data/import/biblio-realm.json
```

**Note**: The `--import-realm` flag in the Dockerfile only works on **first startup** with an empty database. If you've already started Keycloak once, you'll need to use one of the manual import methods above.

## Security Notes

- Change default admin password in production
- Enable SSL/TLS for production deployments
- Use strong passwords for test users
- Enable email verification for production
- Configure SMTP for password reset emails
- Regular backup of Keycloak database
