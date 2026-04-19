const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
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

describe('GET /api/users/me', () => {
  const validUser = createMockUser();
  const accessToken = createMockToken(validUser.id, validUser.role);

  // Profile response (what Prisma returns with select)
  const profileResponse = {
    id: validUser.id,
    societyId: validUser.societyId,
    role: validUser.role,
    name: validUser.name,
    email: validUser.email,
    phone: validUser.phone,
    fcmToken: validUser.fcmToken,
    profilePhotoUrl: null,
    dateOfBirth: null,
    householdMemberCount: null,
    bio: null,
    emergencyContactName: null,
    emergencyContactPhone: null,
    isActive: validUser.isActive,
    createdAt: validUser.createdAt,
    updatedAt: validUser.updatedAt,
    society: { id: 'society-uuid-1', name: 'Test Society', logoUrl: null },
    unitResidents: [],
  };

  describe('successful profile retrieval', () => {
    beforeEach(() => {
      prisma.user.findFirst.mockResolvedValue(profileResponse);
    });

    it('should return 200 with own profile for authenticated user', async () => {
      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(validUser.id);
      expect(res.body.data.name).toBe(validUser.name);
      expect(res.body.data.email).toBe(validUser.email);
      expect(res.body.message).toBe('Profile retrieved');
    });

    it('should NOT include passwordHash in the response', async () => {
      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.passwordHash).toBeUndefined();
    });
  });

  describe('failed profile retrieval', () => {
    it('should return 401 when no token is provided', async () => {
      const res = await request(app)
        .get('/api/users/me');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should return 401 when token is expired', async () => {
      const expiredToken = createExpiredToken(validUser.id, 'access');

      // Small delay to ensure token is expired
      await new Promise(resolve => setTimeout(resolve, 50));

      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${expiredToken}`);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/expired/i);
    });

    it('should return 401 when token is invalid', async () => {
      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', 'Bearer invalid.token.here');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should return 401 when Authorization header format is wrong', async () => {
      const res = await request(app)
        .get('/api/users/me')
        .set('Authorization', accessToken); // missing "Bearer " prefix

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });
});
