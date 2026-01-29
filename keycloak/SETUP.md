# Keycloak Configuration Guide

This guide walks through configuring Keycloak for BiblioHub authentication.

## Access Keycloak Admin Console

1. Open browser: http://localhost:9900/auth/admin/
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`

## Step 1: Create 'biblio' Realm

1. Click on **Master** dropdown (top left)
2. Click **Create Realm**
3. Enter realm details:
   - **Realm name**: `biblio`
   - **Enabled**: ON
4. Click **Create**

## Step 2: Configure Realm Settings

### General Settings
Navigate to: **Realm Settings** → **General**
- **Display name**: `BiblioHub`
- **HTML Display name**: `<b>BiblioHub</b> Authentication`
- **User Profile Enabled**: ON

### Login Settings
Navigate to: **Realm Settings** → **Login**
- **User registration**: OFF (admin creates users)
- **Forgot password**: ON
- **Remember me**: ON
- **Email as username**: OFF
- **Login with email**: ON
- **Duplicate emails**: OFF
- **Verify email**: OFF (can enable later)
- **Require SSL**: None (internal deployment)

### Session Settings
Navigate to: **Realm Settings** → **Sessions**
- **SSO Session Idle**: 30 minutes
- **SSO Session Max**: 8 hours
- **Client Session Idle**: 30 minutes
- **Client Session Max**: 8 hours
- **Offline Session Idle**: 30 days
- **Offline Session Max**: 60 days

### Token Settings
Navigate to: **Realm Settings** → **Tokens**
- **Access Token Lifespan**: 30 minutes
- **Access Token Lifespan For Implicit Flow**: 15 minutes
- **Client login timeout**: 5 minutes
- **Login timeout**: 5 minutes
- **Login action timeout**: 5 minutes
- **Refresh Token Max Reuse**: 0

## Step 3: Create Clients

### Client 1: nginx-gateway (Confidential)
For nginx auth_request integration

1. Navigate to **Clients** → **Create client**
2. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `nginx-gateway`
3. **Capability config**:
   - Client authentication: ON (confidential)
   - Authorization: OFF
   - Authentication flow:
     - Standard flow: ON
     - Direct access grants: ON
     - Implicit flow: OFF
     - Service accounts roles: OFF
4. **Login settings**:
   - Root URL: `http://localhost:9900`
   - Home URL: `http://localhost:9900/`
   - Valid redirect URIs: `http://localhost:9900/*`
   - Valid post logout redirect URIs: `http://localhost:9900/*`
   - Web origins: `http://localhost:9900`
5. Save and note the **Client Secret** from Credentials tab

### Client 2: abb-tts (Public)
For Audiobook Builder frontend

1. Navigate to **Clients** → **Create client**
2. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `abb-tts`
3. **Capability config**:
   - Client authentication: OFF (public)
   - Authorization: OFF
   - Authentication flow:
     - Standard flow: ON
     - Direct access grants: ON
     - Implicit flow: OFF
4. **Login settings**:
   - Root URL: `http://localhost:9900/abb-tts`
   - Home URL: `http://localhost:9900/abb-tts/`
   - Valid redirect URIs: `http://localhost:9900/abb-tts/*`
   - Valid post logout redirect URIs: `http://localhost:9900/abb-tts/*`
   - Web origins: `http://localhost:9900`

### Client 3: biblio-catalog (Public)
For Biblio Catalog (E-book library with OPDS support)

1. Navigate to **Clients** → **Create client**
2. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `biblio-catalog`
3. **Capability config**:
   - Client authentication: OFF (public)
   - Authorization: OFF
   - Authentication flow:
     - Standard flow: ON
     - Direct access grants: ON (for Basic Auth bridge)
     - Implicit flow: OFF
4. **Login settings**:
   - Root URL: `http://localhost:9900/catalog`
   - Home URL: `http://localhost:9900/catalog/`
   - Valid redirect URIs: `http://localhost:9900/catalog/*`
   - Valid post logout redirect URIs: `http://localhost:9900/catalog/*`
   - Web origins: `http://localhost:9900`

### Client 4: tts-silero (Bearer-only)
For internal TTS service

1. Navigate to **Clients** → **Create client**
2. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `tts-silero`
3. **Capability config**:
   - Client authentication: ON
   - Authorization: OFF
   - Authentication flow:
     - Standard flow: OFF
     - Direct access grants: OFF
     - Implicit flow: OFF
     - Service accounts roles: ON (for service-to-service)

### Client 5: tts-openvoice (Bearer-only)
For internal TTS service

1. Navigate to **Clients** → **Create client**
2. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `tts-openvoice`
3. **Capability config**:
   - Client authentication: ON
   - Authorization: OFF
   - Authentication flow:
     - Standard flow: OFF
     - Direct access grants: OFF
     - Implicit flow: OFF
     - Service accounts roles: ON (for service-to-service)

## Step 4: Create Realm Roles

Navigate to **Realm roles** → **Create role**

### Role 1: user
- **Role name**: `user`
- **Description**: `Regular BiblioHub user - access to all services`
- **Composite**: OFF

### Role 2: admin
- **Role name**: `admin`
- **Description**: `BiblioHub administrator - full access including user management`
- **Composite**: OFF

### Role 3: realm-admin (Optional)
- **Role name**: `realm-admin`
- **Description**: `Keycloak realm administrator - can manage users and realm settings`
- **Composite**: ON
- **Composite roles**: Add all roles from `realm-management` client

## Step 5: Create Test Users

Navigate to **Users** → **Create new user**

### User 1: Admin User
1. **Username**: `testadmin`
2. **Email**: `admin@bibliohub.local`
3. **First name**: `Test`
4. **Last name**: `Admin`
5. **Email verified**: ON
6. **Enabled**: ON
7. Click **Create**
8. Go to **Credentials** tab:
   - Click **Set password**
   - Password: `admin123`
   - Temporary: OFF
   - Click **Save**
9. Go to **Role mapping** tab:
   - Click **Assign role**
   - Select `admin` and `user`
   - Click **Assign**

### User 2: Regular User
1. **Username**: `testuser`
2. **Email**: `user@bibliohub.local`
3. **First name**: `Test`
4. **Last name**: `User`
5. **Email verified**: ON
6. **Enabled**: ON
7. Click **Create**
8. Go to **Credentials** tab:
   - Click **Set password**
   - Password: `user123`
   - Temporary: OFF
   - Click **Save**
9. Go to **Role mapping** tab:
   - Click **Assign role**
   - Select `user`
   - Click **Assign**

## Step 6: Configure Client Scopes (Optional)

Navigate to **Client scopes** → **Create client scope**

### Scope: roles
1. **Name**: `roles`
2. **Type**: `Default`
3. **Protocol**: `OpenID Connect`
4. **Display on consent screen**: OFF
5. Click **Create**
6. Go to **Mappers** tab → **Add mapper** → **By configuration**
7. Select **User Realm Role**:
   - **Name**: `realm roles`
   - **Mapper type**: `User Realm Role`
   - **Multivalued**: ON
   - **Token Claim Name**: `realm_access.roles`
   - **Claim JSON Type**: `String`
   - **Add to ID token**: ON
   - **Add to access token**: ON
   - **Add to userinfo**: ON

## Step 7: Export Realm Configuration

1. Navigate to **Realm settings** → **Action** → **Partial export**
2. Select:
   - **Export groups and roles**: ON
   - **Export clients**: ON
   - **Export users**: OFF (for security)
3. Click **Export**
4. Save the JSON file as `biblio-realm.json`

## Verification Checklist

- [ ] Realm 'biblio' created
- [ ] Session timeouts configured (30min access, 8hr session)
- [ ] 5 clients created (nginx-gateway, abb-tts, biblio-catalog, tts-silero, tts-openvoice)
- [ ] 2 roles created (user, admin)
- [ ] 2 test users created (testadmin, testuser)
- [ ] Realm configuration exported

## Next Steps

After completing this configuration:
1. Save the realm export to `keycloak/biblio-realm.json`
2. Note the nginx-gateway client secret
3. Update `.env` file with Keycloak credentials
4. Proceed to Phase 3: Nginx Gateway Integration
