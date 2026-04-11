const request = require('supertest');
const express = require('express');
const cookieParser = require('cookie-parser');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const { createMockToken } = require('../helpers/mockData');

// Silence console in tests
beforeAll(() => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  jest.spyOn(console, 'log').mockImplementation(() => {});
});
afterAll(() => { jest.restoreAllMocks(); });
afterEach(() => { jest.clearAllMocks(); });

// Build a minimal Express app to test the middleware in isolation
function createTestApp(allowedRoles) {
  const app = express();
  app.use(express.json());
  app.use(cookieParser());

  app.get(
    '/test-role',
    authMiddleware,
    roleGuard(...allowedRoles),
    (req, res) => {
      res.status(200).json({ success: true, data: { user: req.user }, message: 'Access granted' });
    }
  );

  return app;
}

describe('roleGuard middleware', () => {
  describe('access granted', () => {
    it('should pass when user has the correct role', async () => {
      const app = createTestApp(['PRAMUKH', 'SECRETARY']);
      const token = createMockToken('user-uuid-1', 'PRAMUKH');

      const res = await request(app)
        .get('/test-role')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Access granted');
    });

    it('should pass when user has any of the allowed roles', async () => {
      const app = createTestApp(['PRAMUKH', 'SECRETARY', 'SUPER_ADMIN']);
      const token = createMockToken('user-uuid-1', 'SECRETARY');

      const res = await request(app)
        .get('/test-role')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('access denied', () => {
    it('should return 403 when user has wrong role', async () => {
      const app = createTestApp(['PRAMUKH', 'SECRETARY']);
      const token = createMockToken('user-uuid-1', 'RESIDENT');

      const res = await request(app)
        .get('/test-role')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/insufficient permissions/i);
    });

    it('should return 403 when WATCHMAN tries to access PRAMUKH-only route', async () => {
      const app = createTestApp(['PRAMUKH']);
      const token = createMockToken('user-uuid-1', 'WATCHMAN');

      const res = await request(app)
        .get('/test-role')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
    });

    it('should return 401 when no token is provided', async () => {
      const app = createTestApp(['PRAMUKH', 'SECRETARY']);

      const res = await request(app)
        .get('/test-role');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should return 401 when token is invalid', async () => {
      const app = createTestApp(['PRAMUKH']);

      const res = await request(app)
        .get('/test-role')
        .set('Authorization', 'Bearer invalid.token.here');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });
});
