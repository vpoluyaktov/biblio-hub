# BiblioHub Keycloak Configuration

This directory contains the custom Keycloak build and configuration files for BiblioHub authentication.

## Files

- **Dockerfile** - Custom Keycloak image with `/auth` base path
- **docker-entrypoint.sh** - Processes realm template with environment variables
- **biblio-realm-template.json** - Pre-configured realm (auto-imported on first startup)
- **SERVICE_INTEGRATION.md** - Integration patterns for developers

## Overview

The `biblio` realm is **automatically created** on first startup with:
- Pre-configured clients for all services
- Default roles (`user`, `admin`, `opds_user`)
- Default users (configurable via `.env`)

No manual setup is required for basic operation.

## Access Points

| URL | Description |
|-----|-------------|
| http://localhost:9900/auth/ | Keycloak Welcome Page |
| http://localhost:9900/auth/admin/ | Admin Console |

**Default Admin Credentials**: `admin` / `admin` (configurable via `KEYCLOAK_ADMIN_PASSWORD`)

## Admin Console Guide

### Logging In

1. Go to http://localhost:9900/auth/admin/
2. Login with admin credentials
3. You'll be in the **Master** realm by default

### Switching to Biblio Realm

1. Click the dropdown in the top-left (shows "Master")
2. Select **biblio**
3. All BiblioHub configuration is in this realm

### Adding a New User

1. Switch to **biblio** realm
2. Navigate to **Users** in the left menu
3. Click **Add user**
4. Fill in:
   - **Username**: (required)
   - **Email**: (optional)
   - **First name** / **Last name**: (optional)
   - **Email verified**: ON (skip email verification)
   - **Enabled**: ON
5. Click **Create**
6. Go to **Credentials** tab:
   - Click **Set password**
   - Enter password
   - **Temporary**: OFF (user won't be forced to change)
   - Click **Save**

### Assigning Roles to a User

1. Go to **Users** → select user
2. Click **Role mapping** tab
3. Click **Assign role**
4. Select roles:
   - `user` - Regular access to all services
   - `admin` - Full access including user management
   - `opds_user` - Required for OPDS feed access (e-readers)
5. Click **Assign**

### Pre-configured Users

| Username | Default Password | Roles | Purpose |
|----------|------------------|-------|---------|
| `hub_admin` | `${BIBLIO_HUB_ADMIN_PASSWORD}` | admin, user, opds_user | Administrator |
| `hub_user` | `${BIBLIO_HUB_USER_PASSWORD}` | user, opds_user | Regular user |
| `opds_user` | `${BIBLIO_OPDS_USER_PASSWORD}` | opds_user | E-reader OPDS access only |

Passwords are set from `.env` file variables.

## Pre-configured Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `biblio-catalog` | Confidential | Biblio Catalog (OIDC + OPDS Basic Auth) |
| `abb-tts` | Public | Audiobook Builder frontend |
| `tts-silero` | Bearer-only | Internal TTS service |
| `tts-openvoice` | Bearer-only | Internal TTS service |

## Session Settings

- **Access Token**: 30 minutes
- **SSO Session Idle**: 30 minutes
- **SSO Session Max**: 8 hours
- **Offline Session**: 30 days

## Maintenance

### Resetting Keycloak (Fresh Start)

To reimport the realm with updated configuration:

```bash
./scripts/stop_stack.sh
rm -rf data/keycloak/db/*
./scripts/start_stack.sh
```

**Warning**: This deletes all users and configuration changes made via Admin Console.

### Backing Up Configuration

1. Login to Admin Console
2. Switch to **biblio** realm
3. Navigate to **Realm settings** → **Action** → **Partial export**
4. Select options and click **Export**
5. Save to `biblio-realm-template.json`

### Updating Keycloak Version

Edit `Dockerfile` and change the version:
```dockerfile
FROM quay.io/keycloak/keycloak:24.0 as builder
```

Then rebuild:
```bash
./scripts/rebuild_stack.sh
./scripts/start_stack.sh
```

## Security Notes

- Change default admin password in production (`KEYCLOAK_ADMIN_PASSWORD`)
- Use strong passwords for all users
- Enable SSL/TLS for production deployments
- Configure SMTP for password reset emails
- Regular backup of Keycloak database (`data/keycloak/db/`)
