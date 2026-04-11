const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const { createMockUser, createMockUnit, createMockToken } = require('../helpers/mockData');

// Mock external dependencies
jest.mock('../../config/db', () => ({
  unit: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
    count: jest.fn(),
  },
  user: {
    findUnique: jest.fn(),
  },
  unitResident: {
    findFirst: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
    count: jest.fn(),
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

describe('Units Module', () => {
  const adminUser = createMockUser({ role: 'SECRETARY' });
  const adminToken = createMockToken(adminUser.id, adminUser.role);
  const mockUnit = createMockUnit();

  describe('GET /api/v1/units', () => {
    it('should return a list of units for the society', async () => {
      prisma.unit.findMany.mockResolvedValue([mockUnit]);
      prisma.unit.count.mockResolvedValue(1);

      const res = await request(app)
        .get('/api/v1/units')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.units).toHaveLength(1);
      expect(res.body.data.units[0].fullCode).toBe('A-101');
    });

    it('should return 401 if not authenticated', async () => {
      const res = await request(app).get('/api/v1/units');
      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/v1/units', () => {
    it('should create a new unit (Admin only)', async () => {
      prisma.unit.findFirst.mockResolvedValue(null); // No existing unit
      prisma.unit.create.mockResolvedValue(mockUnit);


      const res = await request(app)
        .post('/api/v1/units')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          wing: 'A',
          floor: 1,
          unitNumber: '101',
          areaSqft: 1000
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.fullCode).toBe('A-101');
    });

    it('should return 403 for non-admin residents', async () => {
      const residentToken = createMockToken('user-2', 'RESIDENT');
      const res = await request(app)
        .post('/api/v1/units')
        .set('Authorization', `Bearer ${residentToken}`)
        .send({ unitNumber: '102' });

      expect(res.status).toBe(403);
    });
  });

  describe('PATCH /api/v1/units/:id', () => {
    it('should update a unit and respect society isolation', async () => {
      prisma.unit.findUnique.mockResolvedValue(mockUnit);
      prisma.unit.update.mockResolvedValue({ ...mockUnit, notes: 'Updated' });

      const res = await request(app)
        .patch(`/api/v1/units/${mockUnit.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ notes: 'Updated' });

      expect(res.status).toBe(200);
      expect(res.body.data.notes).toBe('Updated');
    });

    it('should return 403 if unit belongs to another society', async () => {
      prisma.unit.findUnique.mockResolvedValue({ ...mockUnit, societyId: 'other-society' });

      const res = await request(app)
        .patch(`/api/v1/units/${mockUnit.id}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ notes: 'Hack' });

      expect(res.status).toBe(403);
    });
  });

  describe('Resident Assignment', () => {
    it('should assign a resident to a unit', async () => {
      prisma.unit.findUnique.mockResolvedValue(mockUnit);
      prisma.user.findUnique.mockResolvedValue({ id: 'user-2', societyId: adminUser.societyId });
      prisma.unitResident.findFirst.mockResolvedValue(null);
      prisma.unitResident.create.mockResolvedValue({ id: 'res-1', unitId: mockUnit.id, userId: 'user-2' });


      const res = await request(app)
        .post(`/api/v1/units/${mockUnit.id}/residents`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ userId: 'user-2', isOwner: false });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
    });
  });
});
