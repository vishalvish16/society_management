# non-production

This folder contains files removed from the active codebase during the production security hardening pass.
They are kept here for reference only and are NOT loaded by the application.

## Contents

| File | Reason removed |
|------|---------------|
| `auth-middleware.js` | Duplicate re-export of `src/middleware/auth.js`. Nothing in the codebase imported this file. |
| `auth.middleware.js` | Duplicate re-export of `src/middleware/auth.js`. Nothing in the codebase imported this file. |

## Notes

- `auth.service.js → generateToken()` was also removed — it used the legacy `JWT_SECRET_KEY` with a 1-hour expiry and was never called anywhere in the codebase. All token generation now goes through `src/utils/jwt.js`.
