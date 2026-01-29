# Service-Level Keycloak Integration Guide

This guide explains how BiblioHub services integrate with Keycloak for authentication. It provides step-by-step instructions and code examples based on the working implementation in `biblio-ebooks-catalog`.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Keycloak Configuration](#keycloak-configuration)
3. [Step-by-Step Integration Guide](#step-by-step-integration-guide)
4. [Backend Implementation (Go)](#backend-implementation-go)
5. [Frontend Implementation (JavaScript)](#frontend-implementation-javascript)
6. [Session Management](#session-management)
7. [Logout Implementation](#logout-implementation)
8. [HTTP Basic Auth for API Clients](#http-basic-auth-for-api-clients)
9. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
10. [Testing](#testing)

---

## Architecture Overview

Each BiblioHub service handles its own authentication flow:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   User Browser  │────▶│  Service (Go)   │────▶│    Keycloak     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │  1. Access /app/      │                       │
        │──────────────────────▶│                       │
        │                       │                       │
        │  2. Check session     │                       │
        │  (no session found)   │                       │
        │                       │                       │
        │  3. Return auth info  │                       │
        │◀──────────────────────│                       │
        │  {mode: "oidc",       │                       │
        │   authenticated: false}│                       │
        │                       │                       │
        │  4. Request login URL │                       │
        │──────────────────────▶│                       │
        │                       │                       │
        │  5. Return login URL  │                       │
        │◀──────────────────────│                       │
        │                       │                       │
        │  6. Redirect to Keycloak                      │
        │──────────────────────────────────────────────▶│
        │                       │                       │
        │  7. User logs in      │                       │
        │                       │                       │
        │  8. Redirect to callback with code            │
        │◀──────────────────────────────────────────────│
        │                       │                       │
        │  9. Callback request  │                       │
        │──────────────────────▶│                       │
        │                       │  10. Exchange code    │
        │                       │──────────────────────▶│
        │                       │                       │
        │                       │  11. Return tokens    │
        │                       │◀──────────────────────│
        │                       │                       │
        │  12. Set session      │                       │
        │      cookie & redirect│                       │
        │◀──────────────────────│                       │
        │                       │                       │
        │  13. Access app       │                       │
        │      (authenticated)  │                       │
        └───────────────────────┴───────────────────────┘
```

---

## Keycloak Configuration

### Keycloak Endpoints

| Endpoint | URL |
|----------|-----|
| **Issuer URL** | `http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}/auth/realms/biblio` |
| **Authorization** | `{issuer}/protocol/openid-connect/auth` |
| **Token** | `{issuer}/protocol/openid-connect/token` |
| **Logout** | `{issuer}/protocol/openid-connect/logout` |
| **UserInfo** | `{issuer}/protocol/openid-connect/userinfo` |

### Existing Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `biblio-catalog` | Confidential | Biblio Catalog (OIDC + OPDS Basic Auth) |
| `abb-tts` | Public | Audiobook Builder frontend |
| `tts-silero` | Bearer-only | Internal TTS service |
| `tts-openvoice` | Bearer-only | Internal TTS service |

### Realm Roles

| Role | Description |
|------|-------------|
| `user` | Regular BiblioHub user |
| `admin` | Administrator with full access |
| `opds_user` | Required for OPDS/API Basic Auth access |

### Adding a New Client

To add a new service, update `keycloak/biblio-realm-template.json`:

```json
{
  "clientId": "your-service",
  "enabled": true,
  "publicClient": false,
  "secret": "${YOUR_SERVICE_CLIENT_SECRET}",
  "redirectUris": [
    "http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}/your-service/*"
  ],
  "webOrigins": ["+"],
  "directAccessGrantsEnabled": true,
  "standardFlowEnabled": true
}
```

---

## Step-by-Step Integration Guide

### Prerequisites

1. Service runs behind nginx gateway at path `/{service-name}/`
2. Service has environment variables:
   - `AUTH_MODE` - `oidc` or `internal`
   - `OIDC_URL` - Keycloak base URL (e.g., `http://keycloak:8080/auth`)
   - `OIDC_REALM` - Realm name (`biblio`)
   - `OIDC_CLIENT_ID` - Client ID for this service
   - `OIDC_CLIENT_SECRET` - Client secret (for confidential clients)
   - `OIDC_REDIRECT_URL` - Callback URL (e.g., `http://10.100.0.4:9900/catalog/api/auth/oidc/callback`)

### Integration Checklist

- [ ] Add OIDC configuration to service config
- [ ] Create OIDC provider with retry logic for startup
- [ ] Implement `/api/auth/info` endpoint
- [ ] Implement `/api/auth/oidc/login` endpoint
- [ ] Implement `/api/auth/oidc/callback` endpoint
- [ ] Implement `/api/auth/oidc/logout` endpoint
- [ ] Update frontend to check auth mode and redirect
- [ ] Handle logout properly with Keycloak redirect
- [ ] Add session cookie management

---

## Backend Implementation (Go)

### 1. Configuration Structure

```go
// config/config.go
type OIDCConfig struct {
    URL          string `yaml:"url"`           // http://keycloak:8080/auth
    Realm        string `yaml:"realm"`         // biblio
    ClientID     string `yaml:"client_id"`     // your-service
    ClientSecret string `yaml:"client_secret"` // from Keycloak
    RedirectURL  string `yaml:"redirect_url"`  // http://host:9900/your-service/api/auth/oidc/callback
}

type AuthConfig struct {
    Mode string     `yaml:"mode"` // "internal" or "oidc"
    OIDC OIDCConfig `yaml:"oidc"`
}
```

### 2. OIDC Provider Implementation

```go
// auth/oidc.go
package auth

import (
    "context"
    "crypto/rand"
    "encoding/base64"
    "encoding/json"
    "fmt"
    "time"

    "github.com/coreos/go-oidc/v3/oidc"
    "golang.org/x/oauth2"
)

type OIDCProvider struct {
    provider     *oidc.Provider
    verifier     *oidc.IDTokenVerifier
    oauth2Config oauth2.Config
    states       map[string]time.Time // state -> expiry time
}

type OIDCConfig struct {
    URL          string
    Realm        string
    ClientID     string
    ClientSecret string
    RedirectURL  string
}

// NewOIDCProvider creates a new OIDC provider with retry logic
func NewOIDCProvider(cfg OIDCConfig) (*OIDCProvider, error) {
    if cfg.URL == "" || cfg.Realm == "" || cfg.ClientID == "" {
        return nil, fmt.Errorf("OIDC not configured")
    }

    ctx := context.Background()
    issuerURL := fmt.Sprintf("%s/realms/%s", cfg.URL, cfg.Realm)

    // Retry connecting to Keycloak with exponential backoff
    // This is important because Keycloak may not be ready when service starts
    var provider *oidc.Provider
    var err error
    maxRetries := 10
    for i := 0; i < maxRetries; i++ {
        provider, err = oidc.NewProvider(ctx, issuerURL)
        if err == nil {
            break
        }
        if i < maxRetries-1 {
            waitTime := time.Duration(1<<uint(i)) * time.Second
            if waitTime > 30*time.Second {
                waitTime = 30 * time.Second
            }
            fmt.Printf("Waiting for OIDC provider (attempt %d/%d): %v\n", i+1, maxRetries, err)
            time.Sleep(waitTime)
        }
    }
    if err != nil {
        return nil, fmt.Errorf("failed to create OIDC provider: %w", err)
    }

    oauth2Config := oauth2.Config{
        ClientID:     cfg.ClientID,
        ClientSecret: cfg.ClientSecret,
        RedirectURL:  cfg.RedirectURL,
        Endpoint:     provider.Endpoint(),
        Scopes:       []string{oidc.ScopeOpenID, "profile", "email", "roles"},
    }

    verifier := provider.Verifier(&oidc.Config{ClientID: cfg.ClientID})

    kp := &OIDCProvider{
        provider:     provider,
        verifier:     verifier,
        oauth2Config: oauth2Config,
        states:       make(map[string]time.Time),
    }

    // Start cleanup goroutine for expired states
    go kp.cleanupStates()

    return kp, nil
}

// GetLoginURL generates the OIDC login URL with state parameter
func (kp *OIDCProvider) GetLoginURL() (string, string, error) {
    state, err := generateState()
    if err != nil {
        return "", "", err
    }

    // Store state with 10 minute expiry
    kp.states[state] = time.Now().Add(10 * time.Minute)

    url := kp.oauth2Config.AuthCodeURL(state)
    return url, state, nil
}

// HandleCallback processes the OAuth2 callback
func (kp *OIDCProvider) HandleCallback(code, state string) (*User, string, error) {
    // Verify state
    expiry, exists := kp.states[state]
    if !exists || time.Now().After(expiry) {
        return nil, "", fmt.Errorf("invalid state")
    }
    delete(kp.states, state)

    ctx := context.Background()

    // Exchange code for token
    oauth2Token, err := kp.oauth2Config.Exchange(ctx, code)
    if err != nil {
        return nil, "", fmt.Errorf("failed to exchange token: %w", err)
    }

    // Extract ID token
    rawIDToken, ok := oauth2Token.Extra("id_token").(string)
    if !ok {
        return nil, "", fmt.Errorf("no id_token in response")
    }

    // Verify ID token
    idToken, err := kp.verifier.Verify(ctx, rawIDToken)
    if err != nil {
        return nil, "", fmt.Errorf("failed to verify ID token: %w", err)
    }

    // Extract claims
    var claims struct {
        Sub               string `json:"sub"`
        PreferredUsername string `json:"preferred_username"`
        Email             string `json:"email"`
        RealmAccess       struct {
            Roles []string `json:"roles"`
        } `json:"realm_access"`
    }

    if err := idToken.Claims(&claims); err != nil {
        return nil, "", fmt.Errorf("failed to parse claims: %w", err)
    }

    // Determine role
    role := "user"
    for _, r := range claims.RealmAccess.Roles {
        if r == "admin" {
            role = "admin"
            break
        }
    }

    user := &User{
        Username: claims.PreferredUsername,
        Role:     role,
    }

    return user, rawIDToken, nil
}

// GetLogoutURL returns the Keycloak logout URL
func (kp *OIDCProvider) GetLogoutURL(redirectURL string) string {
    // Remove "/auth" suffix from AuthURL to get base realm URL
    authURL := kp.oauth2Config.Endpoint.AuthURL
    realmURL := authURL[:len(authURL)-5]
    return fmt.Sprintf("%s/protocol/openid-connect/logout?redirect_uri=%s", realmURL, redirectURL)
}

// AuthenticateWithPassword for Basic Auth (ROPC grant)
func (kp *OIDCProvider) AuthenticateWithPassword(username, password string) (*User, error) {
    ctx := context.Background()

    token, err := kp.oauth2Config.PasswordCredentialsToken(ctx, username, password)
    if err != nil {
        return nil, fmt.Errorf("authentication failed: %w", err)
    }

    rawIDToken, ok := token.Extra("id_token").(string)
    if !ok {
        return nil, fmt.Errorf("no id_token")
    }

    idToken, err := kp.verifier.Verify(ctx, rawIDToken)
    if err != nil {
        return nil, fmt.Errorf("failed to verify token: %w", err)
    }

    var claims struct {
        PreferredUsername string `json:"preferred_username"`
        RealmAccess       struct {
            Roles []string `json:"roles"`
        } `json:"realm_access"`
    }

    if err := idToken.Claims(&claims); err != nil {
        return nil, fmt.Errorf("failed to parse claims: %w", err)
    }

    role := "user"
    for _, r := range claims.RealmAccess.Roles {
        if r == "admin" {
            role = "admin"
            break
        }
    }

    return &User{Username: claims.PreferredUsername, Role: role}, nil
}

func (kp *OIDCProvider) cleanupStates() {
    ticker := time.NewTicker(5 * time.Minute)
    defer ticker.Stop()
    for range ticker.C {
        now := time.Now()
        for state, expiry := range kp.states {
            if now.After(expiry) {
                delete(kp.states, state)
            }
        }
    }
}

func generateState() (string, error) {
    b := make([]byte, 32)
    if _, err := rand.Read(b); err != nil {
        return "", err
    }
    return base64.URLEncoding.EncodeToString(b), nil
}
```

### 3. Session Structure

```go
// auth/session.go
type OIDCSession struct {
    ExpiresAt time.Time `json:"expires_at"`
    Username  string    `json:"username"`
    Role      string    `json:"role"`
}

func (s *OIDCSession) ToJSON() (string, error) {
    data, err := json.Marshal(s)
    if err != nil {
        return "", err
    }
    return base64.StdEncoding.EncodeToString(data), nil
}

func OIDCSessionFromJSON(data string) (*OIDCSession, error) {
    decoded, err := base64.StdEncoding.DecodeString(data)
    if err != nil {
        return nil, err
    }
    var session OIDCSession
    if err := json.Unmarshal(decoded, &session); err != nil {
        return nil, err
    }
    return &session, nil
}
```

### 4. HTTP Handlers

```go
// server/handlers_oidc.go

// GET /api/auth/info - Returns auth mode and current user status
func (s *Server) handleAuthInfo(w http.ResponseWriter, r *http.Request) {
    response := map[string]interface{}{
        "mode": s.authMode, // "oidc" or "internal"
    }

    if s.authMode == "oidc" {
        cookie, err := r.Cookie("oidc_session")
        if err == nil {
            session, err := auth.OIDCSessionFromJSON(cookie.Value)
            if err == nil && session.ExpiresAt.After(time.Now()) {
                response["authenticated"] = true
                response["user"] = map[string]interface{}{
                    "username": session.Username,
                    "role":     session.Role,
                }
            } else {
                response["authenticated"] = false
            }
        } else {
            response["authenticated"] = false
        }
    }

    json.NewEncoder(w).Encode(response)
}

// GET /api/auth/oidc/login - Returns Keycloak login URL
func (s *Server) handleOIDCLogin(w http.ResponseWriter, r *http.Request) {
    loginURL, state, err := s.oidcProvider.GetLoginURL()
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    // Store state in cookie for CSRF protection
    http.SetCookie(w, &http.Cookie{
        Name:     "oauth_state",
        Value:    state,
        Path:     s.basePath,
        MaxAge:   600, // 10 minutes
        HttpOnly: true,
        SameSite: http.SameSiteLaxMode,
    })

    json.NewEncoder(w).Encode(map[string]string{
        "login_url": loginURL,
    })
}

// GET /api/auth/oidc/callback - Handles Keycloak redirect
func (s *Server) handleOIDCCallback(w http.ResponseWriter, r *http.Request) {
    code := r.URL.Query().Get("code")
    state := r.URL.Query().Get("state")

    // Verify state from cookie
    stateCookie, err := r.Cookie("oauth_state")
    if err != nil || stateCookie.Value != state {
        http.Error(w, "Invalid state", http.StatusBadRequest)
        return
    }

    // Clear state cookie
    http.SetCookie(w, &http.Cookie{
        Name:   "oauth_state",
        Value:  "",
        Path:   s.basePath,
        MaxAge: -1,
    })

    // Exchange code for user info
    user, _, err := s.oidcProvider.HandleCallback(code, state)
    if err != nil {
        http.Error(w, err.Error(), http.StatusUnauthorized)
        return
    }

    // Create session
    session := &auth.OIDCSession{
        ExpiresAt: time.Now().Add(8 * time.Hour),
        Username:  user.Username,
        Role:      user.Role,
    }

    sessionJSON, _ := session.ToJSON()

    // Set session cookie
    http.SetCookie(w, &http.Cookie{
        Name:     "oidc_session",
        Value:    sessionJSON,
        Path:     s.basePath,
        Expires:  session.ExpiresAt,
        HttpOnly: true,
        SameSite: http.SameSiteLaxMode,
    })

    // Redirect to main page
    http.Redirect(w, r, s.basePath+"/", http.StatusFound)
}

// POST /api/auth/oidc/logout - Returns Keycloak logout URL
func (s *Server) handleOIDCLogout(w http.ResponseWriter, r *http.Request) {
    // Clear session cookie
    http.SetCookie(w, &http.Cookie{
        Name:     "oidc_session",
        Value:    "",
        Path:     "/",
        MaxAge:   -1,
        HttpOnly: true,
    })

    // Build redirect URL with proper scheme
    scheme := "http"
    if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
        scheme = proto
    }
    redirectURL := fmt.Sprintf("%s://%s%s/", scheme, r.Host, s.basePath)
    logoutURL := s.oidcProvider.GetLogoutURL(redirectURL)

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success":    true,
        "logout_url": logoutURL,
    })
}
```

---

## Frontend Implementation (JavaScript)

### 1. App Initialization

```javascript
const App = {
  user: null,
  oidcRedirectPending: false,  // IMPORTANT: Prevents login screen flash

  async init() {
    await this.checkAuth();
    this.router();
    window.addEventListener('hashchange', () => this.router());
  },

  // ...
};
```

### 2. Authentication Check

```javascript
async checkAuth() {
  try {
    // Check auth mode and current status
    const authInfoRes = await fetch(this.apiUrl('/api/auth/info'));
    const authInfo = await authInfoRes.json();
    
    // If OIDC mode and not authenticated, redirect to Keycloak
    if (authInfo.mode === 'oidc' && !authInfo.authenticated) {
      // IMPORTANT: Set flag BEFORE fetching login URL
      // This prevents the router from showing the internal login screen
      this.oidcRedirectPending = true;
      
      const loginRes = await fetch(this.apiUrl('/api/auth/oidc/login'));
      const loginData = await loginRes.json();
      if (loginData.login_url) {
        window.location.href = loginData.login_url;
        return;
      }
      this.oidcRedirectPending = false;
    }
    
    // If authenticated, set user
    if (authInfo.authenticated) {
      this.user = authInfo.user;
    }
  } catch (e) {
    console.error('Auth check failed:', e);
    this.oidcRedirectPending = false;
  }
}
```

### 3. Router with OIDC Redirect Handling

```javascript
async router() {
  const hash = window.location.hash.slice(1) || 'home';
  const [view, ...params] = hash.split('/');

  // Check auth for protected routes
  // IMPORTANT: Skip redirect to login if OIDC redirect is pending
  // This prevents the internal login screen from flashing
  if (!this.user && !['login', 'setup'].includes(view) && !this.oidcRedirectPending) {
    window.location.hash = '#login';
    return;
  }
  
  // If OIDC redirect is pending, keep showing loading spinner
  if (this.oidcRedirectPending) {
    return;
  }

  // Route to appropriate view
  switch (view) {
    case 'login':
      this.renderLogin();
      break;
    case 'home':
      this.renderHome();
      break;
    // ... other routes
  }
}
```

### 4. Logout Implementation

```javascript
async logout() {
  try {
    // Check auth mode first
    const authInfoRes = await fetch(this.apiUrl('/api/auth/info'));
    const authInfo = await authInfoRes.json();
    
    if (authInfo.mode === 'oidc') {
      // OIDC mode: call OIDC logout endpoint and redirect to Keycloak
      const logoutRes = await fetch(this.apiUrl('/api/auth/oidc/logout'), { method: 'POST' });
      const logoutData = await logoutRes.json();
      this.user = null;
      if (logoutData.logout_url) {
        window.location.href = logoutData.logout_url;
        return;
      }
    } else {
      // Internal mode: use internal logout
      await fetch(this.apiUrl('/api/auth/logout'), { method: 'POST' });
    }
  } catch (e) {
    console.error('Logout failed:', e);
  }
  this.user = null;
  window.location.hash = '#login';
}
```

### 5. HTML Template with Loading Spinner

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Your Service</title>
  <link rel="stylesheet" href="{{.BasePath}}/static/css/style.css">
  <script>
    window.APP_BASE_PATH = "{{.BasePath}}";
  </script>
</head>
<body>
  <div id="app">
    <!-- IMPORTANT: Show loading spinner initially -->
    <!-- This is what users see during OIDC redirect -->
    <div class="loading" style="min-height:100vh">
      <div class="spinner"></div>
    </div>
  </div>
  <script src="{{.BasePath}}/static/js/app.js"></script>
</body>
</html>
```

---

## Session Management

### Session Cookie Settings

| Setting | Value | Reason |
|---------|-------|--------|
| **Name** | `oidc_session` | Service-specific to avoid conflicts |
| **HttpOnly** | `true` | Prevents XSS attacks |
| **Secure** | `true` (production) | HTTPS only |
| **SameSite** | `Lax` | CSRF protection while allowing redirects |
| **Path** | `/{service-name}` | Scoped to service |
| **Max-Age** | 28800 (8 hours) | Matches Keycloak SSO session |

### Session Content

Store minimal user info in the session cookie:

```json
{
  "expires_at": "2026-01-30T00:00:00Z",
  "username": "hub_user",
  "role": "admin"
}
```

**Note**: Do NOT store tokens in cookies. The session is created after token validation, so tokens are not needed for subsequent requests.

---

## Logout Implementation

### Complete Logout Flow

1. **Frontend** calls `POST /api/auth/oidc/logout`
2. **Backend** clears the session cookie
3. **Backend** returns Keycloak logout URL
4. **Frontend** redirects to Keycloak logout URL
5. **Keycloak** clears SSO session and redirects back to service
6. **Service** shows login page (or redirects to Keycloak again)

### Important: Redirect URL Construction

The redirect URL must include the scheme (`http://` or `https://`):

```go
// CORRECT
scheme := "http"
if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
    scheme = proto
}
redirectURL := fmt.Sprintf("%s://%s%s/", scheme, r.Host, basePath)

// WRONG - missing scheme
redirectURL := fmt.Sprintf("%s%s/", r.Host, basePath)
```

---

## HTTP Basic Auth for API Clients

For API clients (like OPDS e-readers) that don't support OAuth2, use Resource Owner Password Credentials (ROPC) grant:

```go
func (s *Server) checkBasicAuth(r *http.Request) (*User, bool) {
    authHeader := r.Header.Get("Authorization")
    if authHeader == "" || !strings.HasPrefix(authHeader, "Basic ") {
        return nil, false
    }

    decoded, err := base64.StdEncoding.DecodeString(authHeader[6:])
    if err != nil {
        return nil, false
    }

    parts := strings.SplitN(string(decoded), ":", 2)
    if len(parts) != 2 {
        return nil, false
    }

    user, err := s.oidcProvider.AuthenticateWithPassword(parts[0], parts[1])
    if err != nil {
        return nil, false
    }

    return user, true
}
```

---

## Common Pitfalls and Solutions

### 1. Login Screen Flash

**Problem**: Internal login screen briefly appears before Keycloak redirect.

**Solution**: Add `oidcRedirectPending` flag and check it in router:

```javascript
// Set flag BEFORE async operations
this.oidcRedirectPending = true;

// In router, skip login redirect if flag is set
if (!this.user && !this.oidcRedirectPending) {
  window.location.hash = '#login';
}
```

### 2. Logout Shows Internal Login Instead of Keycloak

**Problem**: Clicking logout shows internal login screen instead of logging out via Keycloak.

**Solution**: Check auth mode in logout function and redirect to Keycloak logout URL:

```javascript
if (authInfo.mode === 'oidc') {
  const logoutRes = await fetch('/api/auth/oidc/logout', { method: 'POST' });
  const logoutData = await logoutRes.json();
  if (logoutData.logout_url) {
    window.location.href = logoutData.logout_url;
    return;
  }
}
```

### 3. Keycloak Not Ready at Startup

**Problem**: Service fails to start because Keycloak isn't ready yet.

**Solution**: Implement retry logic with exponential backoff:

```go
for i := 0; i < maxRetries; i++ {
    provider, err = oidc.NewProvider(ctx, issuerURL)
    if err == nil {
        break
    }
    waitTime := time.Duration(1<<uint(i)) * time.Second
    time.Sleep(waitTime)
}
```

### 4. Invalid State Error

**Problem**: OAuth2 callback fails with "invalid state" error.

**Causes**:
- State expired (user took too long to login)
- State not stored properly
- Multiple tabs/windows

**Solution**: 
- Store state in both cookie and server-side map
- Set reasonable expiry (10 minutes)
- Clean up expired states periodically

### 5. CORS Errors

**Problem**: Browser blocks requests to Keycloak.

**Solution**: Never make direct browser requests to Keycloak. Always proxy through your backend:

```javascript
// WRONG - direct request to Keycloak
fetch('http://keycloak:8080/auth/...')

// CORRECT - request to your backend
fetch('/api/auth/oidc/login')
```

### 6. Cookie Path Issues

**Problem**: Session cookie not sent with requests.

**Solution**: Set cookie path to match your service base path:

```go
http.SetCookie(w, &http.Cookie{
    Name:  "oidc_session",
    Path:  "/catalog",  // Must match your service path
    // ...
})
```

---

## Testing

### Manual Testing Checklist

1. **Login Flow**
   - [ ] Access service URL
   - [ ] Should see loading spinner (not login form)
   - [ ] Should redirect to Keycloak
   - [ ] Login with `hub_user` / (password from `.env`)
   - [ ] Should redirect back to service
   - [ ] Should see authenticated content

2. **Logout Flow**
   - [ ] Click logout button
   - [ ] Should redirect to Keycloak logout
   - [ ] Should redirect back to service
   - [ ] Should redirect to Keycloak login (not internal login)

3. **SSO Test**
   - [ ] Login to one service
   - [ ] Navigate to another service
   - [ ] Should auto-login (no login prompt)

4. **Session Expiry**
   - [ ] Wait for session to expire (or manually delete cookie)
   - [ ] Refresh page
   - [ ] Should redirect to Keycloak (not internal login)

### API Testing

```bash
# Test Basic Auth (OPDS/API clients)
curl -u opds_user:opds_user http://localhost:9900/catalog/opds/1

# Get access token via ROPC
TOKEN=$(curl -s -X POST http://localhost:9900/auth/realms/biblio/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=hub_user" \
  -d "password=hub_user" \
  -d "grant_type=password" \
  -d "client_id=biblio-catalog" \
  -d "client_secret=biblio-catalog-secret-key-2026" | jq -r '.access_token')

# Use token to access protected API
curl -H "Authorization: Bearer $TOKEN" http://localhost:9900/catalog/api/libraries
```

---

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect Core Spec](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [go-oidc Library](https://github.com/coreos/go-oidc)
- [biblio-ebooks-catalog Implementation](https://github.com/vpoluyaktov/biblio-ebooks-catalog) - Reference implementation

---

*Last updated: 2026-01-29*
