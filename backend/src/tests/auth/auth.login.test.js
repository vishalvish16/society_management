const request = require('supertest');
const bcrypt = require('bcrypt');
const app = require('../../app');
const prisma = require('../../config/db');
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
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(1),
  incr: jest.fn().mockResolvedValue(1),
  expire: jest.fn().mockResolvedValue(1),
  on: jest.fn(),
}));

jest.mock('bcrypt', () => ({
  compare: jest.fn(),
  hash: jest.fn(),
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

describe('POST /api/v1/auth/login', () => {
  const validUser = createMockUser({
    phone: '9876543210',
    email: 'test@example.com',
    isActive: true,
    deletedAt: null,
  });

  describe('successful login', () => {
    beforeEach(() => {
      prisma.user.findFirst.mockResolvedValue(validUser);
      bcrypt.compare.mockResolvedValue(true);
    });

    it('should login with valid phone and password and return 200 with accessToken', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210', password: 'password123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.user).toBeDefined();
      expect(res.body.message).toBe('Login successful');
    });

    it('should login with valid email and password and return 200 with accessToken', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: 'test@example.com', password: 'password123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
    });

    it('should set refreshToken as httpOnly cookie', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210', password: 'password123' });

      expect(res.status).toBe(200);
      const setCookieHeader = res.headers['set-cookie'];
      expect(setCookieHeader).toBeDefined();
      const cookieStr = Array.isArray(setCookieHeader)
        ? setCookieHeader.join('; ')
        : setCookieHeader;
      expect(cookieStr).toMatch(/refreshToken=/);
      expect(cookieStr).toMatch(/HttpOnly/i);
    });

    it('should NOT return passwordHash in the response', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210', password: 'password123' });

      expect(res.status).toBe(200);
      expect(res.body.data.user.passwordHash).toBeUndefined();
      expect(res.body.data.passwordHash).toBeUndefined();
    });
  });

  describe('failed login', () => {
    it('should return 401 for wrong password', async () => {
      prisma.user.findFirst.mockResolvedValue(validUser);
      bcrypt.compare.mockResolvedValue(false);

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210', password: 'wrongpassword' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Invalid credentials');
    });

    it('should return 401 for non-existent phone with same error message as wrong password (no user enumeration)', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '0000000000', password: 'password123' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Invalid credentials');
    });

    it('should return 403 for inactive account', async () => {
      const inactiveUser = createMockUser({ isActive: false });
      prisma.user.findFirst.mockResolvedValue(inactiveUser);

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210', password: 'password123' });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
    });

    it('should return 429 when account is locked out after many failed attempts', async () => {
      const { redis } = require('../../config/redis');
      // Mock redis.get to return '5' (MAX_ATTEMPTS)
      const redisMock = require('../../config/redis');
      redisMock.get.mockResolvedValue('5');

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: 'lockout@example.com', password: 'password123' });

      expect(res.status).toBe(429);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/too many failed attempts/i);
    });


    it('should return 400 when identifier is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ password: 'password123' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/required/i);
    });

    it('should return 400 when password is missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/required/i);
    });

    it('should return 400 when both fields are missing', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should return 400 when password is empty string', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: '9876543210', password: '' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });
});
