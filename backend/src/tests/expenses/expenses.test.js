const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const { createMockUser, createMockExpense, createMockToken } = require('../helpers/mockData');

// Mock external dependencies
jest.mock('../../config/db', () => ({
  society: {
    findUnique: jest.fn(),
  },
  expense: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
    groupBy: jest.fn(),
  },
  expenseAttachment: {
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

describe('Expenses Module', () => {
  const adminUser = createMockUser({ role: 'SECRETARY' });
  const adminToken = createMockToken(adminUser.id, adminUser.role);
  const watchmanUser = createMockUser({ role: 'WATCHMAN', id: 'watch-1' });
  const watchmanToken = createMockToken(watchmanUser.id, watchmanUser.role);
  const mockExpense = createMockExpense();

  beforeEach(() => {
    prisma.society.findUnique.mockResolvedValue({ settings: {} });
  });

  describe('GET /api/v1/expenses', () => {
    it('should return expenses for the society', async () => {
      prisma.expense.findMany.mockResolvedValue([mockExpense]);
      prisma.expense.count.mockResolvedValue(1);

      const res = await request(app)
        .get('/api/v1/expenses')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.expenses).toHaveLength(1);
    });
  });

  describe('POST /api/v1/expenses', () => {
    it('should submit a new expense (Admin/Watchman only)', async () => {
      prisma.expense.create.mockResolvedValue(mockExpense);
      // findUnique inside service should also work
      prisma.expense.findUnique.mockResolvedValue(mockExpense);

      const res = await request(app)
        .post('/api/v1/expenses')
        .set('Authorization', `Bearer ${watchmanToken}`)
        .send({
          title: 'Pump Repair',
          amount: 500,
          category: 'MAINTENANCE',
          expenseDate: '2025-01-10'
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      // The mockData for createMockExpense returns 'Water Leak Repair' as default
      expect(res.body.data.title).toBe('Water Leak Repair');
    });
  });

  describe('PATCH /api/v1/expenses/:id/review', () => {
    it('should approve an expense (Admin only)', async () => {
      prisma.expense.findUnique.mockResolvedValue(mockExpense);
      prisma.expense.update.mockResolvedValue({ ...mockExpense, status: 'APPROVED' });

      const res = await request(app)
        .patch(`/api/v1/expenses/${mockExpense.id}/review`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'APPROVED' });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('APPROVED');
    });

    it('should reject an expense with a reason', async () => {
      prisma.expense.findUnique.mockResolvedValue(mockExpense);
      prisma.expense.update.mockResolvedValue({ ...mockExpense, status: 'REJECTED', rejectionReason: 'Too expensive' });

      const res = await request(app)
        .patch(`/api/v1/expenses/${mockExpense.id}/review`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'REJECTED', rejectionReason: 'Too expensive' });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('REJECTED');
    });
  });

  describe('PATCH /api/v1/expenses/:id/approve', () => {
    it('should allow secretary to approve via /approve when expense_approval is enabled by default', async () => {
      prisma.expense.findUnique.mockResolvedValue(mockExpense);
      prisma.expense.update.mockResolvedValue({ ...mockExpense, status: 'APPROVED' });

      const res = await request(app)
        .patch(`/api/v1/expenses/${mockExpense.id}/approve`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ paymentMethod: 'CASH' });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('APPROVED');
    });
  });

  describe('GET /api/v1/expenses/summary', () => {
    it('should return aggregated expenses summary', async () => {
      prisma.expense.groupBy.mockResolvedValue([
        { category: 'MAINTENANCE', _sum: { amount: 5000 } },
        { category: 'SECURITY', _sum: { amount: 2000 } }
      ]);

      const res = await request(app)
        .get('/api/v1/expenses/summary?startDate=2025-01-01&endDate=2025-01-31')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(2);
    });
  });
});
