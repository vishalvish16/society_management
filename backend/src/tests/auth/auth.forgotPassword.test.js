const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const redis = require('../../config/redis');
const { createMockUser } = require('../helpers/mockData');

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

describe('POST /api/v1/auth/forgot-password', () => {
  const validUser = createMockUser({ phone: '9876543210' });

  describe('successful forgot password', () => {
    beforeEach(() => {
      prisma.user.findFirst.mockResolvedValue(validUser);
      redis.set.mockResolvedValue('OK');
    });

    it('should return 200 for valid phone', async () => {
      const res = await request(app)
        .post('/api/v1/auth/forgot-password')
        .send({ phone: '9876543210' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toMatch(/If that number is registered, an OTP has been sent/);
    });

    // Removed test: should generate a 6-digit OTP (OTP no longer returned to client)

    it('should store OTP in Redis with TTL <= 600 seconds', async () => {
      await request(app)
        .post('/api/v1/auth/forgot-password')
        .send({ phone: '9876543210' });

      expect(redis.set).toHaveBeenCalledWith(
        'otp:9876543210',
        expect.stringMatching(/^\d{6}$/),
        'EX',
        600
      );
    });
  });

  describe('failed forgot password', () => {
    it('should still return 200 for unknown phone number (user enumeration prevention)', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/auth/forgot-password')
        .send({ phone: '0000000000' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toMatch(/If that number is registered/);
    });

    it('should return 400 when phone is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/forgot-password')
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/required/i);
    });
  });
});
