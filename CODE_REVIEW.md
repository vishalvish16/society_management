# Code Review: Society Manager Auth System

**Reviewer:** CodeReviewer Agent
**Date:** 2026-03-24
**Overall Assessment:** Needs Changes

---

## Summary

The codebase demonstrates solid foundational architecture with clean module separation, consistent patterns, and well-thought-out auth flows. However, there are several critical and major issues that must be addressed before this is production-ready, primarily around security (hardcoded JWT fallback secrets, OTP returned in responses, Express 5 compatibility), data integrity (Prisma `update` with non-unique `phone` field), and missing CORS origin configuration for multiple frontends.

---

## Issues Found

### Critical

#### C1. JWT secrets have hardcoded fallback values
**File:** `src/utils/jwt.js:3-4`
```js
const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'access_secret_fallback';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'refresh_secret_fallback';
```
If environment variables are not set (misconfigured deploy, missing `.env`), the server silently falls back to publicly known secrets. An attacker can forge arbitrary tokens.

**Fix:** Remove the fallback values entirely. Throw an error at startup if the env vars are missing:
```js
const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;
if (!ACCESS_SECRET || !REFRESH_SECRET) {
  throw new Error('JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be set');
}
```

---

#### C2. OTP returned in the API response (forgot-password)
**File:** `src/modules/auth/auth.controller.js:107`
```js
return sendSuccess(res, { otp: result.otp }, 'OTP sent');
```
And in `src/modules/auth/auth.service.js:163`:
```js
return { otp };
```
Even with the TODO comment, this is a critical security hole if deployed. The OTP is meant to be a second factor delivered out-of-band (SMS/WhatsApp). Returning it in the HTTP response defeats the purpose entirely.

**Fix:** In production, the service should call an SMS provider and return only a confirmation. For development, gate the OTP return behind an explicit `NODE_ENV === 'development'` check in the controller, and never include it in the service return value for production builds:
```js
const responseData = process.env.NODE_ENV === 'development' ? { otp: result.otp } : {};
return sendSuccess(res, responseData, 'OTP sent');
```

---

#### C3. `prisma.user.update({ where: { phone } })` uses a non-unique field in Prisma
**File:** `src/modules/auth/auth.service.js:183-186`
```js
await prisma.user.update({
  where: { phone },
  data: { passwordHash: newHash },
});
```
The `phone` field has a `@unique` constraint in the schema, so this will work at the Prisma level. However, this is fragile: if `phone` uniqueness were ever relaxed (e.g., soft-deleted users could share phones), this query would fail at runtime. More importantly, the user was looked up by `phone` with `deletedAt: null` in `forgotPassword`, but the `update` here has no such filter, so it could update a soft-deleted user's password if a new user took the same phone number.

**Fix:** Look up the user by `phone` + `deletedAt: null` in `verifyOtpAndResetPassword` and update by `id` instead:
```js
const user = await prisma.user.findFirst({ where: { phone, deletedAt: null } });
if (!user) throw Object.assign(new Error('User not found'), { status: 404 });
await prisma.user.update({ where: { id: user.id }, data: { passwordHash: newHash } });
```

---

### Major

#### M1. Express 5 listed in package.json but cookie-parser may be incompatible
**File:** `package.json:19`
```json
"express": "^5.0.0"
```
Express 5 has significant breaking changes from Express 4, including changes to the `req.query` parser, path parameter syntax, and middleware signature. The `cookie-parser` package and `cors` package may not yet have official Express 5 support. If Express 5 is intentional, the entire middleware stack needs to be verified for compatibility. If not intentional, pin to `^4.18.0`.

**Fix:** Either pin to Express 4 (`"express": "^4.18.0"`) or audit all middleware for Express 5 compatibility and add integration tests.

---

#### M2. No rate limiting on auth endpoints
**File:** `src/modules/auth/auth.routes.js` (all routes)

There is no rate limiting on login, forgot-password, or verify-otp endpoints. This leaves the system vulnerable to:
- Brute-force password attacks on `/login`
- OTP brute-force on `/verify-otp` (6-digit OTP = 1M possibilities, feasible without rate limiting)
- SMS/WhatsApp bombing on `/forgot-password`

**Fix:** Add `express-rate-limit` middleware to auth routes. Suggested limits:
- `/login`: 5 attempts per 15 minutes per IP
- `/forgot-password`: 3 attempts per hour per phone
- `/verify-otp`: 5 attempts per 10 minutes per phone

---

#### M3. OTP not invalidated after failed attempts
**File:** `src/utils/otp.js:24-29`
```js
async function verifyOTP(phone, otp) {
  const key = `otp:${phone}`;
  const stored = await redis.get(key);
  if (!stored) return false;
  return stored === otp;
}
```
The OTP remains in Redis on failed attempts and is only deleted on success (`deleteOTP` is called in `verifyOtpAndResetPassword`). Combined with no rate limiting (M2), this allows unlimited brute-force attempts within the 10-minute TTL window.

**Fix:** Implement an attempt counter in Redis. After N failed attempts (e.g., 5), delete the OTP and require a new one.

---

#### M4. `CORS_ORIGIN` only supports a single origin string
**File:** `src/app.js:12-15`
```js
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true,
}));
```
If the app needs to support multiple origins (e.g., web + admin panel), this breaks. Also, the default `http://localhost:3000` conflicts with the server itself running on port 3000 (see `server.js:6`).

**Fix:** Support comma-separated origins or an array in the env var. Also, consider using a different default port for the API vs. the frontend default.

---

#### M5. Refresh token stored as full JWT string in Redis blacklist key
**File:** `src/modules/auth/auth.service.js:109`
```js
await redis.set(`bl:${refreshToken}`, '1', 'EX', ttl);
```
Refresh tokens can be 300+ characters. Using the entire token as a Redis key is wasteful and could cause issues at scale. Redis key size matters for memory and lookup performance.

**Fix:** Use a hash of the token (e.g., SHA-256) or include a `jti` (JWT ID) claim in the refresh token and blacklist by `jti` instead.

---

#### M6. No validation that the user being updated/deleted belongs to the same society
**File:** `src/modules/users/users.controller.js:83-118` (updateUser)
**File:** `src/modules/users/users.controller.js:125-134` (deleteUser)

A Secretary in Society A could update or delete a user in Society B by knowing their user ID. The `roleGuard` only checks the role, not society membership. The `updateUser` controller checks `isSelf || isSecretary || isPramukh || isSuperAdmin` but never verifies that the target user is in the same society.

**Fix:** In both `updateUser` and `deleteUser`, fetch the target user and verify `targetUser.societyId === req.user.societyId` before proceeding (unless the actor is `SUPER_ADMIN`).

---

#### M7. `uuid` package is in dependencies but never used
**File:** `package.json:23`
```json
"uuid": "^9.0.0"
```
Prisma handles UUID generation via `@default(uuid())` in the schema. The `uuid` npm package is not imported anywhere in the codebase.

**Fix:** Remove `"uuid": "^9.0.0"` from dependencies.

---

### Minor

#### m1. `SALT_ROUNDS` constant duplicated
**File:** `src/modules/auth/auth.service.js:7` and `src/modules/users/users.service.js:4`
```js
const SALT_ROUNDS = 12;
```
This value is defined in two places. If it needs to change, both files must be updated.

**Fix:** Move to a shared config constant (e.g., `src/config/constants.js`) or keep it in one place and import.

---

#### m2. `REFRESH_COOKIE_OPTIONS` missing `domain` for production
**File:** `src/modules/auth/auth.controller.js:4-10`
```js
const REFRESH_COOKIE_OPTIONS = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
  maxAge: 30 * 24 * 60 * 60 * 1000,
  path: '/',
};
```
No `domain` is set. While this defaults to the current domain, it should be explicitly configured for production to prevent cookie scope issues when the API and frontend are on different subdomains.

**Fix:** Add `domain: process.env.COOKIE_DOMAIN || undefined` and add `COOKIE_DOMAIN` to `.env.example`.

---

#### m3. Missing `CORS_ORIGIN` in `.env.example`
**File:** `.env.example` (line 9 - end of file)

The `CORS_ORIGIN` env var is used in `app.js` but not documented in `.env.example`.

**Fix:** Add `CORS_ORIGIN=http://localhost:3000` to `.env.example`.

---

#### m4. Inconsistent error logging: `console.error` used everywhere
**Files:** All controllers and `server.js`

All error logging uses raw `console.error`. This is acceptable for development but doesn't provide structured logging (request IDs, timestamps, severity levels) for production.

**Fix:** Consider using a logging library like `pino` or `winston` with structured JSON output. This is not blocking but should be addressed before production deployment.

---

#### m5. `ExpenseAttachment` model missing `updatedAt`
**File:** `prisma/schema.prisma:216-228`
```prisma
model ExpenseAttachment {
  id            String   @id @default(uuid())
  ...
  createdAt     DateTime @default(now())
  // no updatedAt
```
Per the review checklist, all models should have `createdAt` and `updatedAt`. `ExpenseAttachment` and `VisitorLog` are missing `updatedAt`. `Notification` is also missing `updatedAt`.

**Fix:** Add `updatedAt DateTime @updatedAt` to `ExpenseAttachment`, `VisitorLog`, and `Notification` models.

---

#### m6. Logout route is unauthenticated but functional
**File:** `src/modules/auth/auth.routes.js:10`
```js
router.post('/logout', authController.logout);
```
The logout route does not require the `authMiddleware`. While this works because it reads the refresh token from the cookie (not the access token), it means anyone with the cookie can hit this endpoint. This is generally acceptable, but it also means there is no way to associate the logout action with a specific user for audit logging.

**Fix:** Consider whether logout should require authentication for audit trail purposes. If not needed, this is fine as-is.

---

#### m7. No request body size limit
**File:** `src/app.js:16`
```js
app.use(express.json());
```
No body size limit is configured. The default is 100KB in Express 4, but this should be explicit.

**Fix:** Add a body size limit: `app.use(express.json({ limit: '1mb' }))` or whatever is appropriate for the use case.

---

#### m8. Health check endpoint does not verify Redis connectivity
**File:** `src/app.js:21-23`
```js
app.get('/api/v1/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok' }, message: 'Server is running' });
});
```
The health check only confirms the Express server is running but doesn't verify database or Redis connectivity. A proper health check should ping both dependencies.

**Fix:** Add DB and Redis health checks:
```js
app.get('/api/v1/health', async (req, res) => {
  const dbOk = await prisma.$queryRaw`SELECT 1`.then(() => true).catch(() => false);
  const redisOk = await redis.ping().then(() => true).catch(() => false);
  const status = dbOk && redisOk ? 'ok' : 'degraded';
  res.status(dbOk && redisOk ? 200 : 503).json({
    success: dbOk && redisOk,
    data: { status, database: dbOk, redis: redisOk },
    message: status === 'ok' ? 'All systems operational' : 'Some services are down',
  });
});
```

---

## Checklist Results

### Architecture & Structure
- [x] Module separation (routes / controller / service pattern) -- Clean separation across all modules
- [x] No business logic in controllers (should be in services) -- Controllers only handle request/response; logic is in services
- [x] Config singleton patterns for DB and Redis -- Both are singleton modules
- [x] Proper middleware chain -- auth middleware and roleGuard work correctly
- [x] Consistent error handling pattern -- `Object.assign(new Error(...), { status })` used consistently

### Code Quality
- [x] No duplicated code -- Minor duplication of `SALT_ROUNDS` (see m1), otherwise clean
- [x] Functions are single-responsibility -- Each function does one thing
- [x] Meaningful variable/function names -- Clear and descriptive throughout
- [x] Async/await used consistently -- No `.then()` mixing
- [ ] No unused imports or variables -- `uuid` package unused (M7)
- [x] Proper JSDoc comments on services -- All service functions have JSDoc

### API Design
- [x] Consistent response envelope `{ success, data, message }` -- Used everywhere via `sendSuccess`/`sendError`
- [x] Proper HTTP status codes -- 200, 201, 400, 401, 403, 404, 409, 500 all used correctly
- [x] Input validation present on all POST/PATCH endpoints -- All POST endpoints validate required fields
- [x] Passwords never returned in responses -- `USER_SELECT` excludes `passwordHash`; auth returns only user profile fields
- [x] Pagination structure on list endpoints -- `listUsers` returns `{ users, total, page, limit }`

### Auth Flow
- [x] Access token is short-lived (15m) -- Default `15m` in jwt.js and .env.example
- [x] Refresh token in httpOnly cookie -- Set in auth controller with httpOnly flag
- [x] Refresh token revocation via Redis blacklist -- Implemented in `logout` and checked in `refresh`
- [x] bcrypt used for password hashing -- bcrypt with 12 salt rounds
- [x] OTP stored in Redis with TTL, not in DB -- 10-minute TTL in Redis
- [ ] JWT secrets from env vars (not hardcoded) -- **FAIL**: Fallback values present (C1)

### Database / Prisma
- [x] All models have UUID PKs -- `@id @default(uuid())` on all models
- [ ] createdAt/updatedAt on every model -- **FAIL**: `ExpenseAttachment`, `VisitorLog`, `Notification` missing `updatedAt` (m5)
- [x] Soft-delete via deletedAt where specified -- Present on `User` and `Unit`
- [x] Proper relations defined -- All FK relations properly defined with named relations where needed
- [x] No raw SQL for standard CRUD -- All queries use Prisma client

### Express Best Practices
- [x] CORS configured -- Configured with credentials support
- [x] Cookie parser used -- `cookie-parser` middleware loaded
- [x] Routes versioned under /api/v1 -- All routes under `/api/v1`
- [x] 404 and global error handlers present -- Both defined in app.js

---

## File Summary

| File | Lines | Status |
|------|-------|--------|
| `prisma/schema.prisma` | 283 | Needs minor fixes (m5) |
| `src/config/db.js` | 7 | Pass |
| `src/config/redis.js` | 19 | Pass |
| `src/utils/response.js` | 30 | Pass |
| `src/utils/jwt.js` | 61 | Needs critical fix (C1) |
| `src/utils/otp.js` | 41 | Needs major fix (M3) |
| `src/middleware/auth.js` | 36 | Pass |
| `src/middleware/roleGuard.js` | 23 | Pass |
| `src/modules/auth/auth.service.js` | 196 | Needs critical fix (C2, C3) |
| `src/modules/auth/auth.controller.js` | 146 | Needs critical fix (C2) |
| `src/modules/auth/auth.routes.js` | 18 | Needs major fix (M2) |
| `src/modules/users/users.service.js` | 204 | Pass |
| `src/modules/users/users.controller.js` | 142 | Needs major fix (M6) |
| `src/modules/users/users.routes.js` | 26 | Pass |
| `src/app.js` | 40 | Needs minor fixes (M4, m7, m8) |
| `src/server.js` | 36 | Pass |
| `package.json` | 28 | Needs fix (M1, M7) |
| `.env.example` | 9 | Needs minor fix (m3) |

---

## Priority Action Items

1. **[Critical]** Remove JWT secret fallback values and fail-fast on missing secrets (C1)
2. **[Critical]** Gate OTP response behind `NODE_ENV === 'development'` (C2)
3. **[Critical]** Fix `verifyOtpAndResetPassword` to query by ID after verifying phone+deletedAt (C3)
4. **[Major]** Decide on Express 4 vs 5 and pin accordingly (M1)
5. **[Major]** Add rate limiting to auth endpoints (M2)
6. **[Major]** Add OTP attempt limiting (M3)
7. **[Major]** Verify society membership on user update/delete operations (M6)
8. **[Major]** Remove unused `uuid` dependency (M7)
