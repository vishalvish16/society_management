const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const { createMockUser, createMockVisitor, createMockToken, createMockUnit } = require('../helpers/mockData');

// Mock external dependencies
jest.mock('../../config/db', () => ({
  visitor: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
  },
  unit: {
    findUnique: jest.fn(),
  },
  visitorLog: {
    create: jest.fn(),
  },
  $connect: jest.fn(),
  $disconnect: jest.fn(),
  $transaction: jest.fn((callback) => callback(require('../../config/db'))),

}));

jest.mock('../../config/redis', () => ({
  get: jest.fn(),
  set: jest.fn(),
  on: jest.fn(),
}));

// Silence console in tests
beforeAll(() => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  jest.spyOn(console, 'log').mockImplementation(() => {});
});

afterAll(() => { jest.restoreAllMocks(); });
afterEach(() => { jest.clearAllMocks(); });

describe('Visitors Module', () => {
  const residentUser = createMockUser({ role: 'RESIDENT' });
  const residentToken = createMockToken(residentUser.id, residentUser.role);
  const watchmanUser = createMockUser({ role: 'WATCHMAN', id: 'watch-1' });
  const watchmanToken = createMockToken(watchmanUser.id, watchmanUser.role);
  const mockVisitor = createMockVisitor();
  const mockUnit = createMockUnit();

  describe('GET /api/v1/visitors', () => {
    it('should list visitors for the society', async () => {
      prisma.visitor.findMany.mockResolvedValue([mockVisitor]);
      prisma.visitor.count.mockResolvedValue(1);

      const res = await request(app)
        .get('/api/v1/visitors')
        .set('Authorization', `Bearer ${residentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.visitors).toHaveLength(1);
    });
  });

  describe('POST /api/v1/visitors/invite', () => {
    it('should create a new invitation for a unit', async () => {
      prisma.unit.findUnique.mockResolvedValue(mockUnit); // Return a valid unit in society
      prisma.visitor.create.mockResolvedValue(mockVisitor);

      const res = await request(app)
        .post('/api/v1/visitors/invite')
        .set('Authorization', `Bearer ${residentToken}`)
        .send({
          unitId: 'unit-1',
          visitorName: 'John Doe',
          visitorPhone: '9000000000'
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.qrToken).toBeDefined();
    });

    it('should return 404 if unit does not exist in society', async () => {
      prisma.unit.findUnique.mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/visitors/invite')
        .set('Authorization', `Bearer ${residentToken}`)
        .send({ unitId: 'fake-unit', visitorName: 'X', visitorPhone: '0' });

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/v1/visitors/validate', () => {
    it('should permit entry for a valid QR token (Watchman only)', async () => {
      prisma.visitor.findUnique.mockResolvedValue({
        ...mockVisitor,
        status: 'PENDING',
        qrExpiresAt: new Date(Date.now() + 3600000), // Valid for 1 hour
        unit: { fullCode: 'A-101' }
      });
      prisma.visitor.update.mockResolvedValue({});
      prisma.visitorLog.create.mockResolvedValue({});

      const res = await request(app)
        .post('/api/v1/visitors/validate')
        .set('Authorization', `Bearer ${watchmanToken}`)
        .send({ qrToken: 'qr-1' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toMatch(/Access granted/i);
    });

    it('should deny entry for used tokens', async () => {
      prisma.visitor.findUnique.mockResolvedValue({ ...mockVisitor, status: 'USED' });

      const res = await request(app)
        .post('/api/v1/visitors/validate')
        .set('Authorization', `Bearer ${watchmanToken}`)
        .send({ qrToken: 'used-qr' });

      expect(res.status).toBe(401);
      expect(res.body.message).toMatch(/Token already used/i);
    });

    it('should deny entry for expired tokens', async () => {
      prisma.visitor.findUnique.mockResolvedValue({
        ...mockVisitor,
        status: 'PENDING',
        qrExpiresAt: new Date(Date.now() - 3600000) // Expired 1 hour ago
      });
      prisma.visitor.update.mockResolvedValue({});

      const res = await request(app)
        .post('/api/v1/visitors/validate')
        .set('Authorization', `Bearer ${watchmanToken}`)
        .send({ qrToken: 'old-qr' });

      expect(res.status).toBe(401);
      expect(res.body.message).toMatch(/Token has expired/i);
    });
  });
});
