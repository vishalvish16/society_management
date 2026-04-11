const jwt = require('jsonwebtoken');

const ACCESS_SECRET = 'test_access_secret';
const REFRESH_SECRET = 'test_refresh_secret';

// Ensure environment variables are set for verifyToken in jwt.js
process.env.JWT_ACCESS_SECRET = ACCESS_SECRET;
process.env.JWT_REFRESH_SECRET = REFRESH_SECRET;

/**
 * Create a mock user object with optional overrides.
 * @param {object} overrides
 * @returns {object}
 */
function createMockUser(overrides = {}) {
  return {
    id: 'user-uuid-1',
    societyId: 'society-uuid-1',
    role: 'RESIDENT',
    name: 'Test User',
    email: 'test@example.com',
    phone: '9876543210',
    passwordHash: '$2b$12$LJ3m4ys3Lg/Fy9VpGJ3Gku8qM5XnZv1H2G8kWzY5bN3vCMqx1Hd.e', // "password123"
    fcmToken: null,
    isActive: true,
    deletedAt: null,
    createdAt: new Date('2025-01-01'),
    updatedAt: new Date('2025-01-01'),
    ...overrides,
  };
}

/**
 * Create a mock society object with optional overrides.
 * @param {object} overrides
 * @returns {object}
 */
function createMockSociety(overrides = {}) {
  return {
    id: 'society-uuid-1',
    name: 'Test Society',
    address: '123 Test Street',
    logoUrl: null,
    settings: {},
    createdAt: new Date('2025-01-01'),
    updatedAt: new Date('2025-01-01'),
    ...overrides,
  };
}

/**
 * Create a signed JWT token for testing.
 * @param {string} userId
 * @param {string} role
 * @param {'access'|'refresh'} type
 * @returns {string}
 */
function createMockToken(userId = 'user-uuid-1', role = 'RESIDENT', type = 'access') {
  if (type === 'refresh') {
    return jwt.sign({ id: userId }, REFRESH_SECRET, { expiresIn: '30d' });
  }
  return jwt.sign(
    { id: userId, role, societyId: 'society-uuid-1' },
    ACCESS_SECRET,
    { expiresIn: '15m' }
  );
}

/**
 * Create an expired JWT token for testing.
 * @param {string} userId
 * @param {'access'|'refresh'} type
 * @returns {string}
 */
function createExpiredToken(userId = 'user-uuid-1', type = 'access') {
  const secret = type === 'refresh' ? REFRESH_SECRET : ACCESS_SECRET;
  const payload = type === 'refresh'
    ? { id: userId }
    : { id: userId, role: 'RESIDENT', societyId: 'society-uuid-1' };
  return jwt.sign(payload, secret, { expiresIn: '0s' });
}

/**
 * Create a mock unit object.
 */
function createMockUnit(overrides = {}) {
  return {
    id: 'unit-uuid-1',
    societyId: 'society-uuid-1',
    wing: 'A',
    floor: 1,
    unitNumber: '101',
    subUnit: null,
    fullCode: 'A-101',
    status: 'VACANT',
    areaSqft: 1000,
    notes: null,
    createdAt: new Date('2025-01-01'),
    updatedAt: new Date('2025-01-01'),
    deletedAt: null,
    ...overrides,
  };
}

/**
 * Create a mock maintenance bill object.
 */
function createMockBill(overrides = {}) {
  return {
    id: 'bill-uuid-1',
    societyId: 'society-uuid-1',
    unitId: 'unit-uuid-1',
    billingMonth: new Date('2025-01-01'),
    amount: 2500,
    lateFee: 0,
    totalDue: 2500,
    status: 'PENDING',
    dueDate: new Date('2025-01-15'),
    paidAmount: 0,
    paidAt: null,
    paymentMethod: null,
    receiptUrl: null,
    notes: null,
    createdAt: new Date('2025-01-01'),
    updatedAt: new Date('2025-01-01'),
    ...overrides,
  };
}

/**
 * Create a mock expense object.
 */
function createMockExpense(overrides = {}) {
  return {
    id: 'expense-uuid-1',
    societyId: 'society-uuid-1',
    submittedBy: 'user-uuid-1',
    category: 'MAINTENANCE',
    title: 'Water Leak Repair',
    description: 'Fixed leak in wing B',
    amount: 1500,
    expenseDate: new Date('2025-01-05'),
    status: 'PENDING',
    approvedBy: null,
    approvedAt: null,
    rejectionReason: null,
    createdAt: new Date('2025-01-05'),
    updatedAt: new Date('2025-01-05'),
    ...overrides,
  };
}

/**
 * Create a mock visitor object.
 */
function createMockVisitor(overrides = {}) {
  return {
    id: 'visitor-uuid-1',
    societyId: 'society-uuid-1',
    unitId: 'unit-uuid-1',
    invitedBy: 'user-uuid-1',
    visitorName: 'John Doe',
    visitorPhone: '9000000000',
    expectedArrival: new Date('2025-01-10T10:00:00Z'),
    qrToken: 'qr-token-uuid-1',
    qrExpiresAt: new Date('2025-01-11T10:00:00Z'),
    status: 'PENDING',
    createdAt: new Date('2025-01-09'),
    updatedAt: new Date('2025-01-09'),
    ...overrides,
  };
}

/**
 * Create a mock notification object.
 */
function createMockNotification(overrides = {}) {
  return {
    id: 'notif-uuid-1',
    societyId: 'society-uuid-1',
    targetType: 'ALL',
    targetId: null,
    title: 'General Meeting',
    body: 'Monthly society meeting this Sunday.',
    type: 'ANNOUNCEMENT',
    sentBy: 'user-uuid-1',
    sentAt: new Date('2025-01-01'),
    updatedAt: new Date('2025-01-01'),
    ...overrides,
  };
}

module.exports = {
  createMockUser,
  createMockSociety,
  createMockUnit,
  createMockBill,
  createMockExpense,
  createMockVisitor,
  createMockNotification,
  createMockToken,
  createExpiredToken,
};

