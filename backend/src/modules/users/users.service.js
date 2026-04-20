const bcrypt = require('bcrypt');
const prisma = require('../../config/db');

const { SALT_ROUNDS } = require('../../config/constants');

// Fields to exclude passwordHash from all user queries
const USER_SELECT = {
  id: true,
  societyId: true,
  role: true,
  name: true,
  email: true,
  phone: true,
  fcmToken: true,
  profilePhotoUrl: true,
  dateOfBirth: true,
  householdMemberCount: true,
  bio: true,
  emergencyContactName: true,
  emergencyContactPhone: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
};

/**
 * Get a user's own profile by ID.
 * @param {string} userId
 * @returns {Promise<object>} User profile without passwordHash
 * @throws {Error} If user not found
 */
async function getProfile(userId) {
  const user = await prisma.user.findFirst({
    where: { id: userId, deletedAt: null },
    select: {
      ...USER_SELECT,
      society: {
        select: {
          id: true,
          name: true,
          logoUrl: true,
          plan: { select: { name: true, displayName: true, features: true } },
        },
      },
      unitResidents: {
        select: {
          id: true,
          isOwner: true,
          moveInDate: true,
          moveOutDate: true,
          unit: {
            select: { id: true, fullCode: true, wing: true, unitNumber: true },
          },
        },
      },
    },
  });

  if (!user) {
    throw Object.assign(new Error('User not found'), { status: 404 });
  }

  return user;
}

/**
 * List users in a society with optional filters.
 * @param {string} societyId - The society to list users from
 * @param {{ role?: string, isActive?: boolean, page?: number, limit?: number }} filters
 * @returns {Promise<{ users: object[], total: number, page: number, limit: number }>}
 */
async function listUsers(societyId, filters = {}) {
  const { role, isActive, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = {
    societyId,
    deletedAt: null,
  };

  if (role) where.role = role;
  if (typeof isActive === 'boolean') where.isActive = isActive;

  const [users, total] = await Promise.all([
    prisma.user.findMany({
      where,
      select: USER_SELECT,
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
    }),
    prisma.user.count({ where }),
  ]);

  return { users, total, page, limit };
}

/**
 * Create a new user (resident or watchman) within a society.
 * @param {{ societyId: string, role: string, name: string, email?: string, phone: string, password: string }} data
 * @returns {Promise<object>} Created user without passwordHash
 * @throws {Error} If phone/email already exists
 */
async function createUser(data) {
  const { societyId, role, name, email, phone, password } = data;

  // Check if phone already exists
  const existingPhone = await prisma.user.findUnique({ where: { phone } });
  if (existingPhone) {
    throw Object.assign(new Error('Phone number already registered'), { status: 409 });
  }

  // Check if email already exists (when provided)
  if (email) {
    const existingEmail = await prisma.user.findUnique({ where: { email } });
    if (existingEmail) {
      throw Object.assign(new Error('Email already registered'), { status: 409 });
    }
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

  const user = await prisma.user.create({
    data: {
      societyId,
      role,
      name,
      email: email || null,
      phone,
      passwordHash,
    },
    select: USER_SELECT,
  });

  return user;
}

/**
 * Update a user's profile.
 * @param {string} userId - ID of the user to update
 * @param {{ name?: string, email?: string, phone?: string, fcmToken?: string, isActive?: boolean, profilePhotoUrl?: string|null, dateOfBirth?: Date|null, householdMemberCount?: number|null, bio?: string|null, emergencyContactName?: string|null, emergencyContactPhone?: string|null }} data
 * @param {string|null} callerSocietyId - Society ID of the caller (null for SUPER_ADMIN)
 * @returns {Promise<object>} Updated user without passwordHash
 * @throws {Error} If user not found, society mismatch, or unique constraint violation
 */
async function updateUser(userId, data, callerSocietyId) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || user.deletedAt) {
    throw Object.assign(new Error('User not found'), { status: 404 });
  }

  if (callerSocietyId && user.societyId !== callerSocietyId) {
    throw Object.assign(new Error('Cannot modify users outside your society'), { status: 403 });
  }

  // Check uniqueness if phone is being updated
  if (data.phone && data.phone !== user.phone) {
    const existingPhone = await prisma.user.findUnique({ where: { phone: data.phone } });
    if (existingPhone) {
      throw Object.assign(new Error('Phone number already registered'), { status: 409 });
    }
  }

  // Check uniqueness if email is being updated
  if (data.email && data.email !== user.email) {
    const existingEmail = await prisma.user.findUnique({ where: { email: data.email } });
    if (existingEmail) {
      throw Object.assign(new Error('Email already registered'), { status: 409 });
    }
  }

  // Only allow updating specific fields
  const allowedFields = [
    'name', 'email', 'phone', 'fcmToken', 'isActive',
    'profilePhotoUrl', 'dateOfBirth', 'householdMemberCount', 'bio',
    'emergencyContactName', 'emergencyContactPhone',
  ];
  const updateData = {};
  for (const field of allowedFields) {
    if (data[field] !== undefined) {
      updateData[field] = data[field];
    }
  }

  const updated = await prisma.user.update({
    where: { id: userId },
    data: updateData,
    select: USER_SELECT,
  });

  return updated;
}

/**
 * Soft-delete a user by setting deletedAt and deactivating.
 * @param {string} userId - ID of the user to delete
 * @param {string|null} callerSocietyId - Society ID of the caller (null for SUPER_ADMIN)
 * @returns {Promise<object>} The soft-deleted user
 * @throws {Error} If user not found or society mismatch
 */
async function softDeleteUser(userId, callerSocietyId) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || user.deletedAt) {
    throw Object.assign(new Error('User not found'), { status: 404 });
  }

  if (callerSocietyId && user.societyId !== callerSocietyId) {
    throw Object.assign(new Error('Cannot delete users outside your society'), { status: 403 });
  }

  const deleted = await prisma.user.update({
    where: { id: userId },
    data: {
      deletedAt: new Date(),
      isActive: false,
    },
    select: USER_SELECT,
  });

  return deleted;
}

module.exports = {
  getProfile,
  listUsers,
  createUser,
  updateUser,
  softDeleteUser,
};
