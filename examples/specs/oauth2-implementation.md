# OAuth2 Authentication Implementation

## Overview
Implement OAuth2 authentication supporting Google and GitHub providers with JWT token management and secure session handling.

## Requirements

### Functional Requirements
- Support Google OAuth2 provider
- Support GitHub OAuth2 provider  
- Generate JWT tokens with 1-hour expiration
- Implement refresh token mechanism with 30-day expiration
- Secure HTTP-only cookie-based session management
- User profile synchronization from providers
- Logout functionality

### Non-Functional Requirements
- Token validation response time < 50ms
- Support 1000+ concurrent sessions
- 99.9% uptime for authentication service
- Secure token storage (no plaintext)

## Implementation Details

### 1. OAuth2 Flow

**Login Sequence:**
1. User clicks "Login with Google" or "Login with GitHub"
2. Redirect to provider's OAuth2 consent page
3. User authorizes application
4. Provider redirects back with authorization code
5. Exchange code for access token
6. Fetch user profile from provider
7. Create or update user in database
8. Generate JWT access token
9. Generate refresh token
10. Set secure HTTP-only cookies
11. Redirect to application dashboard

### 2. Dependencies

Add to package.json:
```json
{
  "passport": "^0.6.0",
  "passport-google-oauth20": "^2.0.0",
  "passport-github2": "^0.1.12",
  "jsonwebtoken": "^9.0.0",
  "bcryptjs": "^2.4.3",
  "cookie-parser": "^1.4.6",
  "express-session": "^1.17.3"
}
```

### 3. Environment Configuration

Required environment variables:
```bash
# Google OAuth2
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_CALLBACK_URL=http://localhost:3000/auth/google/callback

# GitHub OAuth2
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
GITHUB_CALLBACK_URL=http://localhost:3000/auth/github/callback

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_here
JWT_EXPIRATION=1h
REFRESH_TOKEN_SECRET=your_refresh_token_secret
REFRESH_TOKEN_EXPIRATION=30d

# Session Configuration
SESSION_SECRET=your_session_secret
SESSION_MAX_AGE=86400000
```

### 4. Code Structure

Create the following structure:
```
src/
├── auth/
│   ├── strategies/
│   │   ├── google.strategy.js       # Google OAuth2 strategy
│   │   └── github.strategy.js       # GitHub OAuth2 strategy
│   ├── middleware/
│   │   ├── authenticate.js          # JWT authentication middleware
│   │   ├── authorize.js             # Authorization middleware
│   │   └── refreshToken.js          # Refresh token middleware
│   ├── services/
│   │   ├── token.service.js         # JWT token generation/validation
│   │   ├── session.service.js       # Session management
│   │   └── user.service.js          # User profile management
│   ├── controllers/
│   │   └── auth.controller.js       # Auth route handlers
│   └── routes.js                    # Auth routes configuration
├── models/
│   ├── User.js                      # User model
│   └── RefreshToken.js              # Refresh token model
└── config/
    └── passport.js                  # Passport configuration
```

### 5. Database Schema

User table:
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  avatar_url TEXT,
  provider VARCHAR(50) NOT NULL,
  provider_id VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP,
  UNIQUE(provider, provider_id)
);
```

Refresh tokens table:
```sql
CREATE TABLE refresh_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(500) UNIQUE NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  revoked BOOLEAN DEFAULT FALSE
);
```

### 6. API Endpoints

```
GET /auth/google
  - Initiates Google OAuth2 flow

GET /auth/google/callback
  - Google OAuth2 callback handler

GET /auth/github
  - Initiates GitHub OAuth2 flow

GET /auth/github/callback
  - GitHub OAuth2 callback handler

POST /auth/refresh
  - Refreshes access token using refresh token
  Request: { "refreshToken": "token" }
  Response: { "accessToken": "new_token", "expiresIn": 3600 }

POST /auth/logout
  - Invalidates current session and tokens
  Response: { "message": "Logged out successfully" }

GET /auth/me
  - Returns current user profile (requires authentication)
  Response: { "id": 1, "email": "user@example.com", "name": "User" }
```

### 7. Security Considerations

- **HTTPS Only:** Use secure cookies in production
- **CSRF Protection:** Implement CSRF tokens
- **Rate Limiting:** Limit auth attempts (5 per minute per IP)
- **Token Rotation:** Rotate refresh tokens on use
- **Secure Storage:** Never log tokens, hash refresh tokens in DB
- **XSS Prevention:** HTTP-only cookies, sanitize user input
- **Session Timeout:** Automatic logout after inactivity

## Testing Requirements

### Unit Tests

- [ ] Token service
  - Test JWT generation with correct claims
  - Test JWT validation with valid token
  - Test JWT validation with expired token
  - Test JWT validation with invalid signature
  - Test refresh token generation
  - Test refresh token validation

- [ ] User service
  - Test user creation from OAuth profile
  - Test user update from OAuth profile
  - Test duplicate user handling

### Integration Tests

- [ ] OAuth2 flows
  - Test Google OAuth2 complete flow
  - Test GitHub OAuth2 complete flow
  - Test callback error handling
  - Test invalid state parameter

- [ ] Token management
  - Test access token refresh flow
  - Test refresh token expiration
  - Test logout token invalidation
  - Test concurrent session handling

### Security Tests

- [ ] Test CSRF protection
- [ ] Test XSS prevention in user data
- [ ] Test token tampering detection
- [ ] Test session hijacking prevention
- [ ] Test rate limiting enforcement
- [ ] Test secure cookie flags

### Performance Tests

- [ ] Test token validation latency (< 50ms)
- [ ] Test concurrent login requests (1000+)
- [ ] Test session lookup performance

## Acceptance Criteria

- [ ] Users can successfully log in with Google
- [ ] Users can successfully log in with GitHub
- [ ] JWT tokens expire after 1 hour
- [ ] Refresh tokens work for 30 days
- [ ] Sessions are stored with HTTP-only cookies
- [ ] Logout properly invalidates session
- [ ] User profile syncs from provider
- [ ] All unit tests pass (coverage > 80%)
- [ ] All integration tests pass
- [ ] Security tests pass
- [ ] Performance targets met
- [ ] Error handling works correctly
- [ ] Documentation is updated

## Error Handling

Handle these scenarios:
- OAuth provider returns error
- Network timeout during OAuth flow
- Invalid authorization code
- Expired refresh token
- Invalid JWT token
- Database connection failure
- Missing environment variables

## Monitoring & Logging

Log the following:
- Successful logins (user ID, provider, timestamp)
- Failed login attempts (IP, reason, timestamp)
- Token refresh events
- Logout events
- OAuth errors (sanitized, no tokens)

## Rollback Plan

If issues arise:
1. Disable OAuth routes via feature flag
2. Restore previous authentication method
3. Migrate active sessions (if needed)
4. Clear refresh token table if corrupted

## Related Documentation

- [Passport.js Documentation](http://www.passportjs.org/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [OAuth 2.0 Specification](https://oauth.net/2/)

---

**Priority:** High
**Estimated Effort:** 3-5 days
**Dependencies:** Database setup, environment configuration
