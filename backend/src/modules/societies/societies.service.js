const prisma = require('../../config/db');
const bcrypt = require('bcrypt');

const SALT_ROUNDS = 12;

const SOCIETY_SELECT = {
  id: true,
  name: true,
  address: true,
  city: true,
  logoUrl: true,
  contactPhone: true,
  contactEmail: true,
  status: true,
  planId: true,
  planStartDate: true,
  planRenewalDate: true,
  settings: true,
  createdAt: true,
  updatedAt: true,
};

const USER_SELECT_NO_PASSWORD = {
  id: true,
  name: true,
  email: true,
  phone: true,
  role: true,
  isActive: true,
  createdAt: true,
};

/**
 * List all societies with pagination, search, and plan info.
 * @param {{ page: number, limit: number, search?: string, status?: string }} params
 */
async function listSocieties({ page = 1, limit = 20, search, status }) {
  const where = {};

  if (search) {
    where.name = { contains: search, mode: 'insensitive' };
  }

  if (status === 'active') where.status = 'active';
  if (status === 'inactive') where.status = 'suspended';

  const [societies, total] = await Promise.all([
    prisma.society.findMany({
      where,
      select: {
        ...SOCIETY_SELECT,
        _count: { select: { users: true, units: true } },
        plan: { select: { id: true, name: true, displayName: true, priceMonthly: true, priceYearly: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.society.count({ where }),
  ]);

  const data = societies.map((s) => ({
    ...s,
    unitCount: s._count.units,
    userCount: s._count.users,
    _count: undefined,
  }));

  return { societies: data, total, page, limit, totalPages: Math.ceil(total / limit) };
}

/**
 * Get full society detail by ID.
 * @param {string} id
 */
async function getSocietyById(id) {
  const society = await prisma.society.findUnique({
    where: { id },
    select: {
      ...SOCIETY_SELECT,
      _count: { select: { users: true, units: true } },
      plan: { select: { id: true, name: true, displayName: true, priceMonthly: true, priceYearly: true, features: true } },
      users: {
        where: { role: 'PRAMUKH', deletedAt: null },
        select: USER_SELECT_NO_PASSWORD,
        take: 1,
      },
    },
  });

  if (!society) return null;

  return {
    ...society,
    unitCount: society._count.units,
    userCount: society._count.users,
    pramukh: society.users[0] || null,
    _count: undefined,
    users: undefined,
  };
}

/**
 * Create a society with optional pramukh user.
 * @param {{ name: string, address?: string, city?: string, contactPhone?: string, contactEmail?: string, planName?: string, pramukh?: { name: string, phone: string, email?: string, password: string } }} data
 */
async function createSociety(data) {
  const { name, address, city, contactPhone, contactEmail, planName, pramukh } = data;

  return prisma.$transaction(async (tx) => {
    // Find plan
    let plan = null;
    if (planName) {
      plan = await tx.plan.findUnique({ where: { name: planName } });
      if (!plan) throw Object.assign(new Error('Plan not found'), { status: 400 });
      if (!plan.isActive) throw Object.assign(new Error('Plan is not active'), { status: 400 });
    } else {
      plan = await tx.plan.findFirst({ where: { isActive: true }, orderBy: { priceMonthly: 'asc' } });
      if (!plan) throw Object.assign(new Error('No active plan available'), { status: 400 });
    }

    const now = new Date();
    const renewalDate = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());

    // 1. Create society
    const society = await tx.society.create({
      data: {
        name,
        address,
        city,
        contactPhone,
        contactEmail,
        planId: plan.id,
        planStartDate: now,
        planRenewalDate: renewalDate,
        status: 'active',
      },
      select: { ...SOCIETY_SELECT, plan: { select: { id: true, name: true, displayName: true } } },
    });

    let pramukhUser = null;
    // 2. Create pramukh user if provided
    if (pramukh) {
      const passwordHash = await bcrypt.hash(pramukh.password, SALT_ROUNDS);
      pramukhUser = await tx.user.create({
        data: {
          societyId: society.id,
          role: 'PRAMUKH',
          name: pramukh.name,
          phone: pramukh.phone,
          email: pramukh.email || null,
          passwordHash,
        },
        select: USER_SELECT_NO_PASSWORD,
      });
    }

    return { society, pramukh: pramukhUser };
  });
}

/**
 * Update society fields.
 * @param {string} id
 * @param {object} data
 */
async function updateSociety(id, data) {
  const allowed = ['name', 'address', 'city', 'contactPhone', 'contactEmail', 'status', 'logoUrl', 'settings'];
  const updateData = {};
  for (const key of allowed) {
    if (data[key] !== undefined) updateData[key] = data[key];
  }

  console.log('[DEBUG] Final updateData for Prisma:', updateData);

  // Handle plan change
  if (data.planName) {
    const plan = await prisma.plan.findUnique({ where: { name: data.planName } });
    if (!plan) throw Object.assign(new Error('Plan not found'), { status: 400 });
    updateData.planId = plan.id;
    updateData.planStartDate = new Date();
    const renewal = new Date();
    renewal.setMonth(renewal.getMonth() + 1);
    updateData.planRenewalDate = renewal;
  }

  return prisma.society.update({
    where: { id },
    data: updateData,
    select: SOCIETY_SELECT,
  });
}

/**
 * Suspend a society and deactivate all its users.
 * @param {string} id
 */
async function deactivateSociety(id) {
  return prisma.$transaction(async (tx) => {
    const society = await tx.society.update({
      where: { id },
      data: { status: 'suspended' },
      select: { id: true, name: true, status: true },
    });

    await tx.user.updateMany({
      where: { societyId: id, deletedAt: null },
      data: { isActive: false },
    });

    return society;
  });
}

module.exports = { listSocieties, getSocietyById, createSociety, updateSociety, deactivateSociety, toggleSocietyStatus, resetPramukhPassword };

async function toggleSocietyStatus(id) {
  return prisma.$transaction(async (tx) => {
    const current = await tx.society.findUnique({ where: { id }, select: { status: true } });
    if (!current) throw Object.assign(new Error('Society not found'), { status: 404 });

    const newStatus = current.status === 'active' ? 'suspended' : 'active';
    const society = await tx.society.update({
      where: { id },
      data: { status: newStatus },
      select: { id: true, name: true, status: true },
    });

    await tx.user.updateMany({
      where: { societyId: id, deletedAt: null },
      data: { isActive: newStatus === 'active' },
    });

    return society;
  });
}

async function resetPramukhPassword(id, newPassword) {
  if (!newPassword || newPassword.length < 8) {
    throw Object.assign(new Error('Password must be at least 8 characters'), { status: 400 });
  }
  const pramukh = await prisma.user.findFirst({
    where: { societyId: id, role: 'PRAMUKH', deletedAt: null },
    select: { id: true },
  });
  if (!pramukh) throw Object.assign(new Error('No Pramukh user found for this society'), { status: 404 });

  const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
  await prisma.user.update({ where: { id: pramukh.id }, data: { passwordHash } });
  return { message: 'Password reset successfully' };
}
