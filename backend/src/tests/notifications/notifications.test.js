const request = require('supertest');
const app = require('../../app');
const prisma = require('../../config/db');
const { createMockUser, createMockNotification, createMockToken } = require('../helpers/mockData');

// Mock external dependencies
jest.mock('../../config/db', () => ({
  notification: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    count: jest.fn(),
  },
  user: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
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

describe('Notifications Module', () => {
  const adminUser = createMockUser({ role: 'SECRETARY' });
  const adminToken = createMockToken(adminUser.id, adminUser.role);
  const residentUser = createMockUser({ role: 'RESIDENT', id: 'res-1' });
  const residentToken = createMockToken(residentUser.id, residentUser.role);
  const mockNotification = createMockNotification();

  describe('GET /api/v1/notifications', () => {
    it('should list notification history for the society (Admin only)', async () => {
      prisma.notification.findMany.mockResolvedValue([mockNotification]);
      prisma.notification.count.mockResolvedValue(1);

      const res = await request(app)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.notifications).toHaveLength(1);
    });

    it('should return 403 for residents', async () => {
      const res = await request(app)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${residentToken}`);
      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/v1/notifications/send', () => {
    it('should trigger a broadcast notification to all residents (Admin only)', async () => {
      prisma.notification.create.mockResolvedValue(mockNotification);
      prisma.user.findMany.mockResolvedValue([{ fcmToken: 'token-1' }, { fcmToken: 'token-2' }]);

      const res = await request(app)
        .post('/api/v1/notifications/send')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          targetType: 'ALL',
          title: 'Meeting',
          body: 'Testing',
          type: 'ANNOUNCEMENT'
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
    });

    it('should send to specific role residents', async () => {
      prisma.notification.create.mockResolvedValue(mockNotification);
      prisma.user.findMany.mockResolvedValue([{ fcmToken: 'watch-token' }]);

      const res = await request(app)
        .post('/api/v1/notifications/send')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          targetType: 'ROLE',
          targetId: 'WATCHMAN',
          title: 'Alert',
          body: 'Test',
          type: 'MANUAL'
        });

      expect(res.status).toBe(201);
    });
  });

  describe('GET /api/v1/notifications/me', () => {
    it('should return recent personalized notifications for the logged-in user', async () => {
      prisma.user.findUnique.mockResolvedValue({ ...residentUser, unitResidents: [{ unitId: 'unit-1' }] });
      prisma.notification.findMany.mockResolvedValue([mockNotification]);

      const res = await request(app)
        .get('/api/v1/notifications/me')
        .set('Authorization', `Bearer ${residentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
    });
  });
});
