# Service-Level Keycloak Integration Guide

This guide explains how BiblioHub services integrate with Keycloak for authentication using service-level authentication rather than gateway-level authentication.

## Architecture Overview

**Service-Level Authentication** means each service handles its own authentication flow:
- Each service checks if the user is authenticated
- If not, the service redirects to Keycloak for login
- After login, Keycloak redirects back to the service with an auth token
- The service validates the token and creates a session

**Benefits:**
- ✅ Simpler architecture - no OAuth2 Proxy complexity
- ✅ More flexible - services can have different auth requirements
- ✅ Better error handling - services control the auth flow
- ✅ Works with existing service auth implementations

## Keycloak Configuration

### Realm: `biblio`
- **Issuer URL**: `http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}/auth/realms/biblio`
- **Admin Console**: `http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}/auth/admin/`
- **Environment Variables**:
  - `BIBLIO_HUB_HOSTNAME` - Hostname or IP where BiblioHub is accessible (default: `localhost`, dev: `10.100.0.4`)
  - `BIBLIO_HUB_PORT` - Port where BiblioHub is accessible (default: `9900`)

### Clients

Each service has a client configured in Keycloak:

| Client ID | Type | Access Type | Purpose |
|-----------|------|-------------|---------|
| `nginx-gateway` | Confidential | confidential | Reserved for future gateway auth |
| `abb-tts` | Public | public | Audiobook Builder TTS frontend |
| `biblio-catalog` | Public | public | Biblio Catalog (E-book library with OPDS) |
| `tts-silero` | Bearer-only | bearer-only | Internal TTS service |
| `tts-openvoice` | Bearer-only | bearer-only | Internal TTS service |

### Roles

- `user` - Regular BiblioHub user (default)
- `admin` - Administrator with full access

### Test Users

- **testadmin** / `admin123` - Has both `admin` and `user` roles
- **testuser** / `user123` - Has `user` role only

## Integration Patterns

### Pattern 1: Public Client (Frontend Applications)

Used by: ABB-TTS, OPDS Server

**Flow:**
1. User accesses service (e.g., `/abb-tts/`)
2. Service checks for valid session cookie
3. If no session, redirect to Keycloak login:
   ```
   http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}/auth/realms/biblio/protocol/openid-connect/auth?
     client_id=abb-tts&
     redirect_uri=http://${BIBLIO_HUB_HOSTNAME}:${BIBLIO_HUB_PORT}/abb-tts/callback&
     response_type=code&
     scope=openid profile email
   ```
4. User logs in via Keycloak
5. Keycloak redirects to callback with authorization code
6. Service exchanges code for access token
7. Service validates token and creates session

**Implementation Example (Go):**

```go
import (
    "github.com/coreos/go-oidc/v3/oidc"
    "golang.org/x/oauth2"
    "os"
    "fmt"
)

// Get BiblioHub base URL from environment
hostname := os.Getenv("BIBLIO_HUB_HOSTNAME")
if hostname == "" {
    hostname = "localhost"
}
port := os.Getenv("BIBLIO_HUB_PORT")
if port == "" {
    port = "9900"
}
baseURL := fmt.Sprintf("http://%s:%s", hostname, port)

// Initialize OIDC provider
issuerURL := fmt.Sprintf("%s/auth/realms/biblio", baseURL)
provider, err := oidc.NewProvider(ctx, issuerURL)
if err != nil {
    log.Fatal(err)
}

// Configure OAuth2
oauth2Config := oauth2.Config{
    ClientID:     "abb-tts",
    RedirectURL:  fmt.Sprintf("%s/abb-tts/callback", baseURL),
    Endpoint:     provider.Endpoint(),
    Scopes:       []string{oidc.ScopeOpenID, "profile", "email"},
}

// Login handler
func handleLogin(w http.ResponseWriter, r *http.Request) {
    state := generateRandomState() // Store in session
    http.Redirect(w, r, oauth2Config.AuthCodeURL(state), http.StatusFound)
}

// Callback handler
func handleCallback(w http.ResponseWriter, r *http.Request) {
    // Verify state
    // Exchange code for token
    token, err := oauth2Config.Exchange(ctx, r.URL.Query().Get("code"))
    if err != nil {
        http.Error(w, "Failed to exchange token", http.StatusInternalServerError)
        return
    }
    
    // Verify ID token
    idToken, err := provider.Verifier(&oidc.Config{ClientID: "abb-tts"}).Verify(ctx, token.Extra("id_token").(string))
    if err != nil {
        http.Error(w, "Failed to verify token", http.StatusUnauthorized)
        return
    }
    
    // Extract claims and create session
    var claims struct {
        Email string `json:"email"`
        Name  string `json:"name"`
    }
    idToken.Claims(&claims)
    
    // Create session cookie
    // Redirect to original page
}
```

### Pattern 2: Bearer-Only Client (Internal Services)

Used by: TTS-Silero, TTS-OpenVoice

**Flow:**
1. Frontend service obtains access token from Keycloak
2. Frontend passes token to internal service via `Authorization: Bearer <token>` header
3. Internal service validates token with Keycloak
4. If valid, process request

**Implementation Example (Go):**

```go
import (
    "github.com/coreos/go-oidc/v3/oidc"
)

// Initialize verifier
provider, _ := oidc.NewProvider(ctx, "http://keycloak:8080/auth/realms/biblio")
verifier := provider.Verifier(&oidc.Config{ClientID: "tts-silero"})

// Middleware to verify bearer token
func authMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        authHeader := r.Header.Get("Authorization")
        if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
        
        token := strings.TrimPrefix(authHeader, "Bearer ")
        idToken, err := verifier.Verify(r.Context(), token)
        if err != nil {
            http.Error(w, "Invalid token", http.StatusUnauthorized)
            return
        }
        
        // Add user info to context
        ctx := context.WithValue(r.Context(), "user", idToken)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

### Pattern 3: HTTP Basic Auth (OPDS Readers)

Used by: OPDS Server (for e-reader compatibility)

**Flow:**
1. E-reader sends HTTP Basic Auth header
2. Service extracts username/password
3. Service authenticates with Keycloak using Resource Owner Password Credentials flow
4. If valid, create session or validate on each request

**Implementation Example (Go):**

```go
func authenticateBasicAuth(username, password string) (*User, error) {
    // Use Keycloak token endpoint with password grant
    data := url.Values{
        "grant_type": {"password"},
        "client_id":  {"biblio-catalog"},
        "username":   {username},
        "password":   {password},
        "scope":      {"openid"},
    }
    
    resp, err := http.PostForm(
        "http://keycloak:8080/auth/realms/biblio/protocol/openid-connect/token",
        data,
    )
    if err != nil || resp.StatusCode != 200 {
        return nil, errors.New("authentication failed")
    }
    
    // Parse token response
    var tokenResp struct {
        AccessToken string `json:"access_token"`
        IDToken     string `json:"id_token"`
    }
    json.NewDecoder(resp.Body).Decode(&tokenResp)
    
    // Verify and extract user info
    // Return user object
}
```

## Session Management

### Session Cookies

Services should use secure session cookies:
- **Name**: `_session` (or service-specific name)
- **HttpOnly**: `true`
- **Secure**: `true` (in production with HTTPS)
- **SameSite**: `Lax`
- **Max-Age**: 28800 (8 hours, matching Keycloak SSO session)

### Token Refresh

Access tokens expire after 30 minutes. Services should:
1. Store refresh token in session
2. Check token expiry before making requests
3. Use refresh token to get new access token when needed

```go
func refreshAccessToken(refreshToken string) (string, error) {
    data := url.Values{
        "grant_type":    {"refresh_token"},
        "client_id":     {"abb-tts"},
        "refresh_token": {refreshToken},
    }
    
    resp, err := http.PostForm(
        "http://keycloak:8080/auth/realms/biblio/protocol/openid-connect/token",
        data,
    )
    // Parse and return new access token
}
```

## Single Sign-On (SSO)

Keycloak provides SSO across all services:
1. User logs in to ABB-TTS
2. Keycloak creates SSO session
3. User navigates to OPDS Server
4. OPDS Server redirects to Keycloak
5. Keycloak sees existing SSO session
6. Keycloak redirects back to OPDS Server with token (no login prompt)

**SSO Session Settings:**
- **SSO Session Idle**: 30 minutes
- **SSO Session Max**: 8 hours
- **Offline Session Idle**: 30 days

## Logout

### Single Logout

To log out from all services:

```go
func handleLogout(w http.ResponseWriter, r *http.Request) {
    // Clear local session
    session.Delete(r)
    
    // Redirect to Keycloak logout
    logoutURL := fmt.Sprintf(
        "http://localhost:9900/auth/realms/biblio/protocol/openid-connect/logout?redirect_uri=%s",
        url.QueryEscape("http://localhost:9900/"),
    )
    http.Redirect(w, r, logoutURL, http.StatusFound)
}
```

## Security Best Practices

1. **Always validate tokens** - Never trust tokens without verification
2. **Use HTTPS in production** - Keycloak requires HTTPS for secure deployments
3. **Rotate client secrets** - Change default secrets in production
4. **Implement CSRF protection** - Use state parameter in OAuth2 flow
5. **Set secure cookie flags** - HttpOnly, Secure, SameSite
6. **Handle token expiry** - Implement refresh token flow
7. **Log authentication events** - Monitor for suspicious activity

## Troubleshooting

### Common Issues

**Issue**: Redirect loop after login
- **Cause**: Session not being created properly
- **Fix**: Check session cookie settings and storage

**Issue**: Token validation fails
- **Cause**: Clock skew or wrong issuer URL
- **Fix**: Sync server time, verify issuer URL matches Keycloak

**Issue**: CORS errors
- **Cause**: Frontend making direct requests to Keycloak
- **Fix**: Use backend-for-frontend pattern, proxy through service

**Issue**: SSO not working across services
- **Cause**: Different cookie domains
- **Fix**: Ensure all services use same cookie domain (localhost)

## Testing

### Manual Testing

1. Access service: `http://localhost:9900/abb-tts/`
2. Should redirect to Keycloak login
3. Login with `testuser` / `user123`
4. Should redirect back to service
5. Access another service: `http://localhost:9900/catalog/`
6. Should auto-login (SSO)

### API Testing

```bash
# Get access token
TOKEN=$(curl -s -X POST http://localhost:9900/auth/realms/biblio/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser" \
  -d "password=user123" \
  -d "grant_type=password" \
  -d "client_id=abb-tts" | jq -r '.access_token')

# Use token to access protected API
curl -H "Authorization: Bearer $TOKEN" http://localhost:9900/abb-tts/api/books
```

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect Core Spec](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [go-oidc Library](https://github.com/coreos/go-oidc)
