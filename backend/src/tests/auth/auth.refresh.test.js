const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const redis = require('../../config/redis');
const { createMockUser, createMockToken, createExpiredToken } = require('../helpers/mockData');

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

describe('POST /api/v1/auth/refresh', () => {
  const validUser = createMockUser();

  describe('successful token refresh', () => {
    beforeEach(() => {
      redis.get.mockResolvedValue(null); // not blacklisted
      prisma.user.findUnique.mockResolvedValue(validUser);
    });

    it('should return 200 with new accessToken when refresh token cookie is valid', async () => {
      const refreshToken = createMockToken(validUser.id, validUser.role, 'refresh');

      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .set('Cookie', `refreshToken=${refreshToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
      expect(typeof res.body.data.accessToken).toBe('string');
      expect(res.body.message).toBe('Token refreshed');
    });
  });

  describe('failed token refresh', () => {
    it('should return 401 when no refresh token cookie is present', async () => {
      const res = await request(app)
        .post('/api/v1/auth/refresh');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should return 401 when refresh token is expired', async () => {
      const expiredToken = createExpiredToken(validUser.id, 'refresh');

      // Small delay to ensure token is expired
      await new Promise(resolve => setTimeout(resolve, 50));

      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .set('Cookie', `refreshToken=${expiredToken}`);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should return 401 when refresh token is blacklisted', async () => {
      const refreshToken = createMockToken(validUser.id, validUser.role, 'refresh');
      redis.get.mockResolvedValue('1'); // blacklisted

      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .set('Cookie', `refreshToken=${refreshToken}`);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/revoked/i);
    });

    it('should return 401 when refresh token is invalid', async () => {
      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .set('Cookie', 'refreshToken=invalid.token.here');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });
});
