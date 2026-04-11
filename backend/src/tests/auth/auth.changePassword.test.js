const request = require('supertest');
const bcrypt = require('bcrypt');
const app = require('../../app');
const prisma = require('../../config/db');
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

describe('POST /api/v1/auth/change-password', () => {
  const validUser = createMockUser();
  const accessToken = createMockToken(validUser.id, validUser.role);

  describe('successful password change', () => {
    beforeEach(() => {
      prisma.user.findUnique.mockResolvedValue(validUser);
      bcrypt.compare.mockResolvedValue(true);
      bcrypt.hash.mockResolvedValue('$2b$12$newhashedpassword');
      prisma.user.update.mockResolvedValue({ ...validUser, passwordHash: '$2b$12$newhashedpassword' });
    });

    it('should return 200 when current password is correct', async () => {
      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: 'password123', newPassword: 'newpassword123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('Password changed');
    });

    it('should update the password hash in the database', async () => {
      await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: 'password123', newPassword: 'newpassword123' });

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: validUser.id },
        data: { passwordHash: '$2b$12$newhashedpassword' },
      });
    });
  });

  describe('failed password change', () => {
    it('should return 400 when current password is incorrect', async () => {
      prisma.user.findUnique.mockResolvedValue(validUser);
      bcrypt.compare.mockResolvedValue(false);

      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: 'wrongpassword', newPassword: 'newpassword123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/current password/i);
    });

    it('should return 401 when not authenticated', async () => {
      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .send({ currentPassword: 'password123', newPassword: 'newpassword123' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should return 400 when currentPassword is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ newPassword: 'newpassword123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should return 400 when newPassword is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ currentPassword: 'password123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should return 400 when both fields are missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });
});
