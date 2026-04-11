# Security Audit Report — Society Manager Auth System

**Auditor:** SecurityReviewer Agent
**Date:** 2026-03-24
**Scope:** `backend/` — Authentication, authorization, user management, OTP flow
**Files Reviewed:** 18 files (all backend source, config, schema)

---

## DEPLOYMENT BLOCKERS — CRITICAL ISSUES

> **The following issues MUST be resolved before any production deployment.**

### CRITICAL-1: OTP Returned in API Response (CWE-200, OWASP A02)

**File:** `src/modules/auth/auth.controller.js:107`
**Severity:** CRITICAL

The `forgotPassword` endpoint returns the OTP directly in the HTTP response body:

```js
return sendSuccess(res, { otp: result.otp }, 'OTP sent');
```

There is a `TODO` comment acknowledging this, but there is **no conditional guard** — this code runs in ALL environments including production. Any attacker can call `/api/v1/auth/forgot-password` with a phone number and receive the OTP in the response, allowing immediate account takeover.

**Proof of Concept:**
```bash
curl -X POST http://target/api/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"phone":"9876543210"}'
# Response: { "success": true, "data": { "otp": "482917" }, "message": "OTP sent" }
# Attacker now uses this OTP to reset the victim's password
```

**Remediation:**
Guard behind `NODE_ENV`:
```js
const responseData = process.env.NODE_ENV === 'development' ? { otp: result.otp } : {};
return sendSuccess(res, responseData, 'If an account exists, an OTP has been sent');
```

---

### CRITICAL-2: Hardcoded JWT Secret Fallbacks (CWE-798, OWASP A02)

**File:** `src/utils/jwt.js:3-4`
**Severity:** CRITICAL

```js
const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'access_secret_fallback';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'refresh_secret_fallback';
```

If the environment variables are not set (common in misconfigured deployments), the application silently falls back to publicly known, hardcoded secret strings. An attacker who knows these strings (they are in the source code) can forge arbitrary JWTs and impersonate any user, including `SUPER_ADMIN`.

**Proof of Concept:**
```js
const jwt = require('jsonwebtoken');
const forgedToken = jwt.sign(
  { id: 'any-user-uuid', role: 'SUPER_ADMIN', societyId: 'any-society' },
  'access_secret_fallback',
  { expiresIn: '1h' }
);
// Use forgedToken as Bearer token to access any endpoint
```

**Remediation:**
Fail fast if secrets are not configured:
```js
const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;
if (!ACCESS_SECRET || !REFRESH_SECRET) {
  throw new Error('FATAL: JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be set');
}
```

---

## HIGH Severity Findings

### HIGH-1: User Enumeration via Forgot Password (CWE-204, OWASP A07)

**File:** `src/modules/auth/auth.service.js:156-158`
**Severity:** HIGH

The `forgotPassword` function throws a distinct error when the phone number is not found:

```js
if (!user) {
  throw Object.assign(new Error('No account found with this phone number'), { status: 404 });
}
```

This allows an attacker to enumerate which phone numbers are registered in the system by observing different error messages for valid vs. invalid phone numbers.

**Proof of Concept:**
```bash
# Non-existent user:
curl -X POST .../forgot-password -d '{"phone":"0000000000"}'
# => 404 "No account found with this phone number"

# Existing user:
curl -X POST .../forgot-password -d '{"phone":"9876543210"}'
# => 200 "OTP sent"
```

**Remediation:**
Always return the same success response regardless of whether the user exists:
```js
if (!user) {
  return { otp: null }; // Silently do nothing
}
```
And in the controller, always respond: `"If an account exists with this phone, an OTP has been sent."`

---

### HIGH-2: No Rate Limiting on Authentication Endpoints (CWE-307, OWASP A07)

**Files:** `src/modules/auth/auth.routes.js`, `src/app.js`
**Severity:** HIGH

There is no rate limiting middleware on any endpoint. The following are particularly vulnerable:

| Endpoint | Risk |
|---|---|
| `POST /auth/login` | Brute-force password attacks |
| `POST /auth/forgot-password` | OTP flooding / SMS abuse |
| `POST /auth/verify-otp` | OTP brute-force (6-digit = 1M combinations) |
| `POST /auth/refresh` | Token abuse |

A 6-digit OTP with no rate limiting can be brute-forced in under 20 minutes with concurrent requests.

**Remediation:**
Add `express-rate-limit` middleware:
- Login: 5 attempts per 15 minutes per IP
- Forgot-password: 3 attempts per 15 minutes per phone
- Verify-OTP: 5 attempts per 15 minutes per phone (lock OTP after 5 failures)

---

### HIGH-3: No Account Lockout After Failed Login Attempts (CWE-307, OWASP A07)

**File:** `src/modules/auth/auth.service.js:16-53`
**Severity:** HIGH

The `login` function does not track failed attempts. An attacker can try unlimited passwords against any account with no lockout or delay.

**Remediation:**
Track failed attempts in Redis (e.g., `login_fail:<identifier>`). Lock the account or enforce exponential backoff after 5 failed attempts within 15 minutes.

---

### HIGH-4: No Cross-Society Authorization Check on User Updates/Deletes (CWE-639, OWASP A01)

**File:** `src/modules/users/users.controller.js:83-119`
**Severity:** HIGH

The `updateUser` endpoint checks if the caller is a Secretary/Pramukh but does NOT verify that the target user belongs to the same society. A Secretary from Society A could update any user in Society B by providing their UUID.

```js
// Line 86-91: Checks role, but never checks:
// targetUser.societyId === req.user.societyId
```

Similarly, `deleteUser` at line 125-134 has no society-scoping check.

**Proof of Concept:**
```bash
# Secretary of Society A updates a user in Society B
curl -X PATCH http://target/api/v1/users/<society-b-user-id> \
  -H "Authorization: Bearer <society-a-secretary-token>" \
  -d '{"isActive": false}'
# => 200 Success — user in different society is deactivated
```

**Remediation:**
In `updateUser` and `deleteUser`, fetch the target user and verify `targetUser.societyId === req.user.societyId` before proceeding.

---

### HIGH-5: Global Error Handler Leaks Internal Error Messages (CWE-209, OWASP A05)

**File:** `src/app.js:35-38`
**Severity:** HIGH

```js
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  sendError(res, err.message || 'Internal Server Error', err.status || 500);
});
```

In production, `err.message` could contain stack traces, database connection strings, SQL errors, or internal system paths. This raw error message is sent directly to the client.

**Remediation:**
In production, always send a generic error message:
```js
const message = process.env.NODE_ENV === 'production'
  ? 'Internal Server Error'
  : err.message;
```

---

## MEDIUM Severity Findings

### MED-1: Refresh Token Cookie Missing `secure` Flag in Development (CWE-614, OWASP A02)

**File:** `src/modules/auth/auth.controller.js:6`
**Severity:** MEDIUM

```js
secure: process.env.NODE_ENV === 'production',
```

This is correctly conditional, but if `NODE_ENV` is not set or is set to anything other than `'production'` (e.g., `'staging'`, `'qa'`), the cookie will be sent over plain HTTP. This is acceptable for local dev but risky for staging/QA environments.

**Remediation:**
Use `secure: process.env.NODE_ENV !== 'development'` so only explicit development mode disables the flag.

---

### MED-2: No Input Sanitization or Validation Library (CWE-20, OWASP A03)

**Files:** All controllers
**Severity:** MEDIUM

Input validation is done manually with simple truthy checks (e.g., `if (!identifier || !password)`). There is no:
- Phone number format validation (accepts arbitrary strings)
- Email format validation
- Input length limits (could pass extremely long strings)
- Type checking (could pass objects instead of strings)

While Prisma prevents SQL injection, malformed input could cause unexpected behavior or be stored as garbage data.

**Remediation:**
Add a validation library such as `joi`, `zod`, or `express-validator`. Validate:
- Phone: regex pattern for expected format
- Email: standard email format
- Passwords: min 8 chars (6 is weak), complexity rules
- All string fields: maximum length

---

### MED-3: Password Minimum Length Too Short (CWE-521, OWASP A07)

**Files:** `src/modules/auth/auth.controller.js:80`, `src/modules/users/users.controller.js:58`
**Severity:** MEDIUM

Minimum password length is 6 characters. NIST SP 800-63B recommends a minimum of 8 characters. No complexity requirements are enforced (uppercase, numbers, special characters).

**Remediation:**
Increase minimum to 8 characters. Consider checking against a breached-password list (e.g., `haveibeenpwned` API).

---

### MED-4: Logout Does Not Require Authentication (CWE-613, OWASP A07)

**File:** `src/modules/auth/auth.routes.js:10`
**Severity:** MEDIUM

```js
router.post('/logout', authController.logout);
```

The logout endpoint is public. While the impact is limited (it only blacklists the refresh token from the cookie), an attacker who steals a refresh token could use this endpoint to force-logout the legitimate user.

**Remediation:**
Add `authMiddleware` to the logout route so only authenticated users can trigger logout.

---

### MED-5: Prisma Query Logging in Development Exposes Sensitive Data (CWE-532, OWASP A09)

**File:** `src/config/db.js:3-4`
**Severity:** MEDIUM

```js
log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
```

In development mode, all Prisma queries are logged to stdout. This includes queries that fetch `passwordHash` values (in the login flow). If development logs are collected or shared, password hashes could be exposed.

**Remediation:**
Remove `'query'` from development logging, or ensure query logs are never persisted or transmitted.

---

### MED-6: CORS Origin Falls Back to Localhost (CWE-942, OWASP A05)

**File:** `src/app.js:13`
**Severity:** MEDIUM

```js
origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
```

If `CORS_ORIGIN` is not set in production, CORS allows `http://localhost:3000`. This is low risk in most scenarios but could be exploited if an attacker runs a local server on the same machine or network.

**Remediation:**
Fail with an error if `CORS_ORIGIN` is not set in production:
```js
if (process.env.NODE_ENV === 'production' && !process.env.CORS_ORIGIN) {
  throw new Error('CORS_ORIGIN must be set in production');
}
```

---

## LOW Severity Findings

### LOW-1: `verifyToken` Exported Unnecessarily (CWE-749)

**File:** `src/utils/jwt.js:55-61`
**Severity:** LOW

The generic `verifyToken(token, secret)` function is exported in the module. If accidentally called with the wrong secret or used in other modules, it could lead to token confusion attacks. Only the purpose-specific wrappers (`verifyAccessToken`, `verifyRefreshToken`) should be exported.

**Remediation:**
Remove `verifyToken` from `module.exports`.

---

### LOW-2: No `express.json()` Body Size Limit (CWE-400, OWASP A05)

**File:** `src/app.js:15`
**Severity:** LOW

```js
app.use(express.json());
```

No body size limit is specified. An attacker could send extremely large JSON payloads to cause memory exhaustion. Express 5 defaults to 100KB but this should be explicitly set.

**Remediation:**
```js
app.use(express.json({ limit: '10kb' }));
```

---

### LOW-3: Missing Security Headers (CWE-693, OWASP A05)

**File:** `src/app.js`
**Severity:** LOW

No security headers are set. Missing headers include:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Strict-Transport-Security` (HSTS)
- `X-XSS-Protection`

**Remediation:**
Add the `helmet` middleware:
```js
const helmet = require('helmet');
app.use(helmet());
```

---

### LOW-4: `.env.example` Contains Realistic-Looking Defaults (CWE-798)

**File:** `.env.example:1`
**Severity:** LOW

```
DATABASE_URL=postgresql://user:password@localhost:5432/society_manager
```

While this is clearly placeholder data, the format could trick someone into using the defaults directly. The JWT secret placeholders (`your_access_secret_here`) are more clearly non-functional.

**Remediation:**
Use clearly invalid placeholders: `DATABASE_URL=postgresql://CHANGE_ME:CHANGE_ME@localhost:5432/society_manager`

---

## Audit Checklist Results

### Authentication Security (OWASP A07)
- [x] Passwords hashed with bcrypt (cost factor 12) — `auth.service.js:7`
- [x] No plaintext passwords stored
- [!] JWT secrets have hardcoded fallbacks — **CRITICAL-2**
- [x] Access tokens default to 15m expiry — `jwt.js:5`
- [x] Refresh token blacklisted on logout via Redis — `auth.service.js:100-114`
- [ ] **MISSING:** No account lockout or rate limiting — **HIGH-2, HIGH-3**
- [~] Login uses same "Invalid credentials" message for not-found and wrong-password — PASS
- [!] Forgot-password leaks user existence — **HIGH-1**

### Injection Vulnerabilities (OWASP A03)
- [x] No string concatenation in queries — Prisma used throughout
- [x] Prisma ORM provides parameterized queries by default
- [x] No `eval()` or dynamic `require()`
- [~] Minimal input validation — **MED-2**

### Sensitive Data Exposure (OWASP A02)
- [x] `USER_SELECT` excludes `passwordHash` from API responses — `users.service.js:7-18`
- [x] JWT payload contains only `id`, `role`, `societyId` — `auth.service.js:40`
- [x] `.env.example` has placeholder values only
- [!] OTP returned in API response — **CRITICAL-1**

### Broken Access Control (OWASP A01)
- [x] Protected routes use `authMiddleware` — `users.routes.js:9`
- [x] Role guard applied to admin endpoints — `users.routes.js:15,18,24`
- [!] No cross-society check on update/delete — **HIGH-4**
- [x] Secretary limited to creating RESIDENT/WATCHMAN only — `users.controller.js:53-55`

### Security Misconfiguration (OWASP A05)
- [x] CORS restricted to specific origin (not wildcard `*`)
- [x] HttpOnly + Secure + SameSite set on refresh cookie — `auth.controller.js:4-10`
- [!] Internal error messages exposed in production — **HIGH-5**
- [ ] **MISSING:** No rate limiting on any endpoint — **HIGH-2**

### OTP Security
- [x] OTP is 6 digits using `crypto.randomInt` (cryptographically random) — `otp.js:12`
- [x] OTP expires in 10 minutes — `otp.js:4`
- [x] OTP deleted after successful use — `auth.service.js:180`
- [ ] **MISSING:** No rate limiting on forgot-password or verify-otp — **HIGH-2**
- [!] OTP returned in production responses — **CRITICAL-1**

### Cryptography (OWASP A02)
- [!] JWT fallback secrets are hardcoded — **CRITICAL-2**
- [x] bcrypt cost factor is 12 (adequate) — `auth.service.js:7`
- [x] No MD5 or SHA1 used for passwords
- [x] UUIDs used for all IDs — `schema.prisma` uses `@default(uuid())`

---

## Risk Summary

| Severity | Count | Deployment Impact |
|----------|-------|-------------------|
| CRITICAL | 2 | **BLOCKS DEPLOYMENT** |
| HIGH | 5 | Must fix before production |
| MEDIUM | 6 | Should fix before production |
| LOW | 4 | Fix in next sprint |

**Overall Risk Level: HIGH** — Two critical vulnerabilities (OTP exposure and JWT fallback secrets) would allow complete account takeover in a production deployment. Five additional high-severity issues significantly weaken the security posture.

---

## Recommended Priority Order

1. **CRITICAL-1** — Remove OTP from API response (immediate)
2. **CRITICAL-2** — Remove JWT secret fallbacks, fail on missing env (immediate)
3. **HIGH-2** — Add rate limiting (`express-rate-limit`) to auth endpoints
4. **HIGH-4** — Add cross-society authorization checks
5. **HIGH-1** — Fix user enumeration in forgot-password
6. **HIGH-3** — Add account lockout after failed logins
7. **HIGH-5** — Suppress error details in production
8. **MED-1 through MED-6** — Address in order listed
9. **LOW-1 through LOW-4** — Address in next sprint
