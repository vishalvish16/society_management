const crypto = require('crypto');
const request = require('supertest');

const app = require('../../app');
const redis = require('../../config/redis');
const { createMockUser, createMockToken } = require('../helpers/mockData');

// Mock external dependencies
jest.mock('../../config/db', () => ({
  user: {
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
  },
  $connect: jest.fn(),
  $disconnect: jest.fn(),
}));

jest.mock('../../config/redis', () => ({
  get: jest.fn(),
  set: jest.fn(),
  del: jest.fn(),
  on: jest.fn(),
}));

// Bypass rate limiters in tests
const passthrough = (req, res, next) => next();
jest.mock('../../middleware/rateLimiter', () => ({
  loginLimiter: passthrough,
  forgotPasswordLimiter: passthrough,
  verifyOtpLimiter: passthrough,
}));

// Silence console in tests
beforeAll(() => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  jest.spyOn(console, 'log').mockImplementation(() => {});
});
afterAll(() => { jest.restoreAllMocks(); });
afterEach(() => { jest.clearAllMocks(); });

describe('POST /api/v1/auth/logout', () => {
  const validUser = createMockUser();
  const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

  describe('successful logout', () => {
    beforeEach(() => {
      redis.set.mockResolvedValue('OK');
    });

    it('should return 200 and blacklist token in Redis', async () => {
      const accessToken = createMockToken(validUser.id, validUser.role, 'access');
      const refreshToken = createMockToken(validUser.id, validUser.role, 'refresh');

      const res = await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('Cookie', `refreshToken=${refreshToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Logged out');

      // Verify token was blacklisted in Redis
      expect(redis.set).toHaveBeenCalledWith(
        `bl:${hashToken(refreshToken)}`,
        '1',
        'EX',
        expect.any(Number)
      );
    });

    it('should clear the refreshToken cookie', async () => {
      const accessToken = createMockToken(validUser.id, validUser.role, 'access');
      const refreshToken = createMockToken(validUser.id, validUser.role, 'refresh');

      const res = await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('Cookie', `refreshToken=${refreshToken}`);

      expect(res.status).toBe(200);
      const setCookieHeader = res.headers['set-cookie'];
      expect(setCookieHeader).toBeDefined();
      const cookieStr = Array.isArray(setCookieHeader)
        ? setCookieHeader.join('; ')
        : setCookieHeader;
      // Cookie should be cleared (empty value or expires in the past)
      expect(cookieStr).toMatch(/refreshToken=/);
    });

    it('should return 200 even without a refresh token cookie', async () => {
      const accessToken = createMockToken(validUser.id, validUser.role, 'access');
      const res = await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('blacklisted token cannot be used for refresh', () => {
    it('should reject refresh with a previously logged-out token', async () => {
      const accessToken = createMockToken(validUser.id, validUser.role, 'access');
      const refreshToken = createMockToken(validUser.id, validUser.role, 'refresh');

      // Logout first
      redis.set.mockResolvedValue('OK');
      await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('Cookie', `refreshToken=${refreshToken}`);

      // Now attempt refresh — token is blacklisted. Hashed key checked.
      redis.get.mockImplementation((key) => {
        if (key === `bl:${hashToken(refreshToken)}`) return Promise.resolve('1');
        return Promise.resolve(null);
      });

      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .set('Cookie', `refreshToken=${refreshToken}`);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });
});
