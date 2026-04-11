const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const { createMockUser, createMockBill, createMockToken } = require('../helpers/mockData');

// Mock external dependencies
jest.mock('../../config/db', () => ({
  maintenanceBill: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
    createMany: jest.fn(),
  },
  unit: {
    findMany: jest.fn(),
  },
  $connect: jest.fn(),
  $disconnect: jest.fn(),
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

describe('Bills Module', () => {
  const adminUser = createMockUser({ role: 'SECRETARY' });
  const adminToken = createMockToken(adminUser.id, adminUser.role);
  const residentUser = createMockUser({ role: 'RESIDENT', id: 'res-1' });
  const residentToken = createMockToken(residentUser.id, residentUser.role);
  const mockBill = createMockBill();

  describe('GET /api/v1/bills', () => {
    it('should return bills for the user\'s society', async () => {
      prisma.maintenanceBill.findMany.mockResolvedValue([mockBill]);
      prisma.maintenanceBill.count.mockResolvedValue(1);

      const res = await request(app)
        .get('/api/v1/bills')
        .set('Authorization', `Bearer ${residentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.bills).toHaveLength(1);
    });
  });

  describe('POST /api/v1/bills/generate', () => {
    it('should bulk generate bills for all occupied units (Admin only)', async () => {
      // Mock occupied units and current bills
      prisma.unit.findMany.mockResolvedValue([{ id: 'unit-1' }, { id: 'unit-2' }]);
      prisma.maintenanceBill.findMany.mockResolvedValue([]);
      prisma.maintenanceBill.createMany.mockResolvedValue({ count: 2 });

      const res = await request(app)
        .post('/api/v1/bills/generate')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          month: '2025-02',
          defaultAmount: 2000,
          dueDate: '2025-02-15'
        });

      expect(res.status).toBe(201);
      expect(res.body.data.count).toBe(2);
    });

    it('should prevent double generation for the same month', async () => {
      prisma.unit.findMany.mockResolvedValue([{ id: 'unit-1' }]);
      prisma.maintenanceBill.findMany.mockResolvedValue([{ unitId: 'unit-1' }]);


      const res = await request(app)
        .post('/api/v1/bills/generate')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          month: '2025-01',
          defaultAmount: 2000,
          dueDate: '2025-01-15'
        });

      expect(res.status).toBe(400); // Bad Request (Already generated)
    });
  });

  describe('POST /api/v1/bills/:id/pay', () => {
    it('should record payment for a bill and mark as PAID', async () => {
      prisma.maintenanceBill.findUnique.mockResolvedValue(mockBill);
      prisma.maintenanceBill.update.mockResolvedValue({ ...mockBill, status: 'PAID', paidAmount: 2500 });

      const res = await request(app)
        .post(`/api/v1/bills/${mockBill.id}/pay`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          paidAmount: 2500,
          paymentMethod: 'UPI',
          notes: 'Paid via PhonePe'
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('PAID');
    });

    it('should mark as PARTIAL if amount is less than total', async () => {
      prisma.maintenanceBill.findUnique.mockResolvedValue(mockBill);
      prisma.maintenanceBill.update.mockResolvedValue({ ...mockBill, status: 'PARTIAL', paidAmount: 1000 });

      const res = await request(app)
        .post(`/api/v1/bills/${mockBill.id}/pay`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          paidAmount: 1000,
          paymentMethod: 'CASH'
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('PARTIAL');
    });
  });
});
