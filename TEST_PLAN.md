# Society Manager - Test Plan

## Overview

Unit tests for the Society Manager backend auth system. All tests use mocked Prisma (database) and Redis dependencies via Jest, with supertest for HTTP-level testing against the Express app.

## Test Coverage Summary

| Module | File | Scenarios |
|---|---|---|
| Auth - Login | `src/tests/auth/auth.login.test.js` | 8 tests: valid phone/email login, httpOnly cookie, no passwordHash leak, wrong password, non-existent user, inactive account, missing fields, empty password |
| Auth - Forgot Password | `src/tests/auth/auth.forgotPassword.test.js` | 5 tests: valid phone OTP generation, 6-digit format, Redis TTL, unknown phone, missing phone |
| Auth - Verify OTP | `src/tests/auth/auth.verifyOtp.test.js` | 8 tests: valid OTP reset, password hash update, OTP deletion from Redis, wrong OTP, expired OTP, missing fields |
| Auth - Change Password | `src/tests/auth/auth.changePassword.test.js` | 6 tests: correct current password, hash update, wrong current password, unauthenticated, missing fields |
| Auth - Refresh Token | `src/tests/auth/auth.refresh.test.js` | 5 tests: valid refresh, missing cookie, expired token, blacklisted token, invalid token |
| Auth - Logout | `src/tests/auth/auth.logout.test.js` | 4 tests: blacklist in Redis, cookie cleared, no cookie graceful, blacklisted token rejected on refresh |
| Users - Profile | `src/tests/users/users.me.test.js` | 6 tests: authenticated profile, no passwordHash, no token, expired token, invalid token, wrong header format |
| Middleware - Role Guard | `src/tests/middleware/roleGuard.test.js` | 5 tests: correct role passes, any allowed role passes, wrong role 403, no token 401, invalid token 401 |

**Total: 47 test scenarios**

## How to Run Tests

```bash
# Install dependencies (includes jest and supertest)
cd backend
npm install

# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage report
npm run test:coverage

# Run a specific test file
npx jest src/tests/auth/auth.login.test.js
```

## Mocking Strategy

- **Prisma** (`src/config/db.js`): Mocked via `jest.mock()` in each test file. All `prisma.user.*` methods are replaced with `jest.fn()`.
- **Redis** (`src/config/redis.js`): Mocked via `jest.mock()` in each test file. `get`, `set`, `del` methods are `jest.fn()`.
- **bcrypt**: Mocked where needed to control password comparison results without actual hashing.
- **JWT**: Uses real `jsonwebtoken` with test secrets (`test_access_secret` / `test_refresh_secret`) set via `setupFiles`.
- **HTTP**: Uses `supertest` against the Express `app` instance (no real server started).

## What is NOT Covered (and Why)

| Area | Reason |
|---|---|
| Integration tests with real PostgreSQL | Requires running database; planned for CI pipeline with Docker |
| Integration tests with real Redis | Requires running Redis instance; planned for CI pipeline |
| SMS/WhatsApp OTP delivery | External service; would require service-level mocking or E2E tests |
| Rate limiting | Depends on express-rate-limit configuration; test in E2E |
| User CRUD operations (list, create, update, delete) | Outside auth scope; planned for separate test suite |
| File upload / expense attachments | Outside auth scope |
| Visitor QR code flow | Outside auth scope |
| Concurrent request handling | Requires load testing tools (k6, Artillery) |
| CORS and security headers | Best tested via E2E or manual verification |

## Test File Structure

```
backend/
  jest.config.js
  src/
    tests/
      setup.js                          # Environment variables for test
      helpers/
        mockData.js                     # Factory functions for mock data
      auth/
        auth.login.test.js
        auth.forgotPassword.test.js
        auth.verifyOtp.test.js
        auth.changePassword.test.js
        auth.refresh.test.js
        auth.logout.test.js
      users/
        users.me.test.js
      middleware/
        roleGuard.test.js
```
