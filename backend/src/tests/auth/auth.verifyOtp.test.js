const request = require('supertest');
const bcrypt = require('bcrypt');
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
  get: jest.fn((key) => {
    if (key.startsWith('otp_attempts:')) return Promise.resolve('0');
    if (key.startsWith('otp:')) return Promise.resolve('123456');
    return Promise.resolve(null);
  }),
  set: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(1),
  incr: jest.fn().mockResolvedValue(1),
  expire: jest.fn().mockResolvedValue(1),
  on: jest.fn(),
}));


jest.mock('bcrypt', () => ({
  compare: jest.fn(),
  hash: jest.fn().mockResolvedValue('$2b$12$newhashedpassword'),
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

describe('POST /api/v1/auth/verify-otp', () => {
  const validUser = createMockUser({ phone: '9876543210' });

  describe('successful OTP verification', () => {
    beforeEach(() => {
      redis.del.mockResolvedValue(1);
      prisma.user.findFirst.mockResolvedValue(validUser);
      prisma.user.update.mockResolvedValue(validUser);
    });

    it('should return 200 and reset password with valid OTP', async () => {
      const res = await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', otp: '123456', newPassword: 'newpass123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Password reset successful');
    });

    it('should update the password hash in the database', async () => {
      await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', otp: '123456', newPassword: 'newpass123' });

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: validUser.id },
        data: { passwordHash: expect.any(String) },
      });
    });

    it('should delete OTP from Redis after successful use', async () => {
      await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', otp: '123456', newPassword: 'newpass123' });

      expect(redis.del).toHaveBeenCalledWith('otp:9876543210', 'otp_attempts:9876543210');

    });
  });

  describe('failed OTP verification', () => {
    it('should return 400 for wrong OTP', async () => {

      const res = await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', otp: '999999', newPassword: 'newpass123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/invalid|expired/i);
    });

    it('should return 400 for expired OTP (not in Redis)', async () => {
      redis.get.mockImplementationOnce(() => Promise.resolve(null));

      const res = await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', otp: '123456', newPassword: 'newpass123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/invalid|expired/i);
    });

    it('should return 400 when phone is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ otp: '123456', newPassword: 'newpass123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should return 400 when otp is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', newPassword: 'newpass123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should return 400 when newPassword is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/verify-otp')
        .send({ phone: '9876543210', otp: '123456' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });
});
