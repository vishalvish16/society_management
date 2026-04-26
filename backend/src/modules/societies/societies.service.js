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

  if (status === 'active') where.status = 'ACTIVE';
  if (status === 'inactive') where.status = 'SUSPENDED';

  const [societies, total] = await Promise.all([
    prisma.society.findMany({
      where,
      select: {
        ...SOCIETY_SELECT,
        _count: { select: { users: true, units: true } },
        plan: { select: { id: true, name: true, displayName: true, pricePerUnit: true, maxUnits: true, maxUsers: true } },
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
      plan: { select: { id: true, name: true, displayName: true, pricePerUnit: true, maxUnits: true, maxUsers: true, features: true } },
      users: {
        where: { role: { in: ['PRAMUKH', 'CHAIRMAN'] }, deletedAt: null },
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
    chairman: society.users[0] || null,
    _count: undefined,
    users: undefined,
  };
}

/**
 * Create a society with optional chairman user.
 * @param {{ name: string, address?: string, city?: string, contactPhone?: string, contactEmail?: string, planName?: string, trialDays?: number, settings?: any, chairman?: { name: string, phone: string, email?: string, password: string } }} data
 */
async function createSociety(data) {
  const { name, address, city, contactPhone, contactEmail, planName, chairman, trialDays, settings } = data;

  return prisma.$transaction(async (tx) => {
    // Find plan
    let plan = null;
    if (planName) {
      plan = await tx.plan.findUnique({ where: { name: planName } });
      if (!plan) throw Object.assign(new Error('Plan not found'), { status: 400 });
      if (!plan.isActive) throw Object.assign(new Error('Plan is not active'), { status: 400 });
    } else {
      plan = await tx.plan.findFirst({ where: { isActive: true }, orderBy: { pricePerUnit: 'asc' } });
      if (!plan) throw Object.assign(new Error('No active plan available'), { status: 400 });
    }

    const now = new Date();
    let renewalDate = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());
    if (trialDays && Number.isFinite(Number(trialDays)) && Number(trialDays) > 0) {
      renewalDate = new Date(now.getTime() + Number(trialDays) * 24 * 60 * 60 * 1000);
    }

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
        status: 'ACTIVE',
        settings: settings ?? undefined,
      },
      select: { ...SOCIETY_SELECT, plan: { select: { id: true, name: true, displayName: true } } },
    });

    let chairmanUser = null;
    // 2. Create chairman user if provided
    if (chairman) {
      const passwordHash = await bcrypt.hash(chairman.password, SALT_ROUNDS);
      chairmanUser = await tx.user.create({
        data: {
          societyId: society.id,
          role: 'PRAMUKH',
          name: chairman.name,
          phone: chairman.phone,
          email: chairman.email || null,
          passwordHash,
        },
        select: USER_SELECT_NO_PASSWORD,
      });
    }

    return { society, chairman: chairmanUser };
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
    const plan = await prisma.plan.findUnique({ where: { name: String(data.planName).toLowerCase().trim() } });
    if (!plan) throw Object.assign(new Error(`Plan '${data.planName}' not found.`), { status: 400 });
    if (!plan.isActive) throw Object.assign(new Error(`Plan '${plan.displayName}' is not active.`), { status: 400 });
    
    // Check if society's current unit count fits in new plan
    const unitCount = await prisma.unit.count({ where: { societyId: id, deletedAt: null } });
    if (plan.maxUnits !== -1 && unitCount > plan.maxUnits) {
      throw Object.assign(new Error(`Cannot downgrade to ${plan.displayName}: Society has ${unitCount} units, but plan maximum is ${plan.maxUnits}.`), { status: 400 });
    }

    updateData.planId = plan.id;
    updateData.planStartDate = new Date();
    
    // Duration check
    const duration = data.planDuration || 'MONTHLY';
    const renewal = new Date();
    if (duration === 'YEARLY') renewal.setFullYear(renewal.getFullYear() + 1);
    else if (duration === 'SIX_MONTHS') renewal.setMonth(renewal.getMonth() + 6);
    else if (duration === 'THREE_MONTHS') renewal.setMonth(renewal.getMonth() + 3);
    else renewal.setMonth(renewal.getMonth() + 1);

    updateData.planRenewalDate = renewal;
    updateData.planDuration = duration;
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
      data: { status: 'SUSPENDED' },
      select: { id: true, name: true, status: true },
    });

    await tx.user.updateMany({
      where: { societyId: id, deletedAt: null },
      data: { isActive: false },
    });

    return society;
  });
}

module.exports = { listSocieties, getSocietyById, createSociety, updateSociety, deactivateSociety, toggleSocietyStatus, resetChairmanPassword, upsertSocietyChairman };

async function toggleSocietyStatus(id) {
  return prisma.$transaction(async (tx) => {
    const current = await tx.society.findUnique({ where: { id }, select: { status: true } });
    if (!current) throw Object.assign(new Error('Society not found'), { status: 404 });

    const newStatus = current.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
    const society = await tx.society.update({
      where: { id },
      data: { status: newStatus },
      select: { id: true, name: true, status: true },
    });

    await tx.user.updateMany({
      where: { societyId: id, deletedAt: null },
      data: { isActive: newStatus === 'ACTIVE' },
    });

    return society;
  });
}

function _generatePassword(length = 10) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
  let out = '';
  for (let i = 0; i < length; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

async function resetChairmanPassword(id, newPassword, newName, mode) {
  const autoMode = String(mode || '').toLowerCase() === 'auto';
  if (!newName && !newPassword && !autoMode) {
    throw Object.assign(new Error('At least name or password is required'), { status: 400 });
  }

  const chairman = await prisma.user.findFirst({
    where: { societyId: id, role: { in: ['PRAMUKH', 'CHAIRMAN'] }, deletedAt: null },
    select: { id: true },
  });
  if (!chairman) throw Object.assign(new Error('No Chairman user found for this society'), { status: 404 });

  const data = {};
  if (newName) data.name = newName;
  let effectivePassword = newPassword;
  if (autoMode && (!effectivePassword || String(effectivePassword).trim().isEmpty)) {
    effectivePassword = _generatePassword(10);
  }
  if (effectivePassword) {
    if (String(effectivePassword).length < 8) {
      throw Object.assign(new Error('Password must be at least 8 characters'), { status: 400 });
    }
    data.passwordHash = await bcrypt.hash(String(effectivePassword), SALT_ROUNDS);
  }

  await prisma.user.update({ where: { id: chairman.id }, data });
  // Intentionally do not return the generated password for security.
  return { message: autoMode ? 'Chairman password auto-reset successfully' : 'Chairman updated successfully' };
}

async function upsertSocietyChairman(societyId, input) {
  const { name, phone, email, password } = input || {};
  if (!name || !phone) {
    throw Object.assign(new Error('Chairman name and phone are required'), { status: 400 });
  }

  const society = await prisma.society.findUnique({ where: { id: societyId }, select: { id: true } });
  if (!society) throw Object.assign(new Error('Society not found'), { status: 404 });

  const existing = await prisma.user.findFirst({
    where: { societyId, role: { in: ['PRAMUKH', 'CHAIRMAN'] }, deletedAt: null },
    select: { id: true },
  });

  const data = {
    name,
    phone,
    email: email || null,
  };

  if (password) {
    if (password.length < 8) {
      throw Object.assign(new Error('Password must be at least 8 characters'), { status: 400 });
    }
    data.passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  }

  if (existing) {
    await prisma.user.update({ where: { id: existing.id }, data });
    return { message: 'Chairman updated successfully' };
  }

  if (!password) {
    throw Object.assign(new Error('Password is required to create chairman'), { status: 400 });
  }

  await prisma.user.create({
    data: {
      societyId,
      role: 'PRAMUKH',
      name,
      phone,
      email: email || null,
      passwordHash: data.passwordHash,
    },
    select: USER_SELECT_NO_PASSWORD,
  });

  return { message: 'Chairman created successfully' };
}
