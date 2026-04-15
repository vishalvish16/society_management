const prisma = require('../../config/db');

function generateEntryCode() {
  return String(Math.floor(100000 + Math.random() * 900000)); // 6-digit numeric
}

async function listDomesticHelp(societyId, filters = {}) {
  const { unitId, type, status, page = 1, limit = 20 } = filters;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const where = { societyId };
  if (unitId) where.unitId = unitId;
  if (type) where.type = type;
  if (status) where.status = status;

  const [items, total] = await Promise.all([
    prisma.domesticHelp.findMany({
      where,
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' },
      include: { unit: { select: { fullCode: true } } },
    }),
    prisma.domesticHelp.count({ where }),
  ]);

  return { items, total, page: parseInt(page), limit: parseInt(limit) };
}

async function createDomesticHelp(societyId, registeredById, data) {
  const { unitId, name, type, phone, allowedDays, allowedFrom, allowedTo, notes } = data;

  if (!unitId || !name || !type) {
    throw Object.assign(new Error('unitId, name, and type are required'), { status: 400 });
  }

  const unit = await prisma.unit.findUnique({ where: { id: unitId } });
  if (!unit || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found in your society'), { status: 404 });
  }

  // Generate unique entry code
  let entryCode;
  let attempts = 0;
  do {
    entryCode = generateEntryCode();
    const existing = await prisma.domesticHelp.findUnique({ where: { entryCode } });
    if (!existing) break;
    attempts++;
  } while (attempts < 5);

  return prisma.domesticHelp.create({
    data: {
      societyId,
      unitId,
      registeredById,
      name,
      type,
      phone: phone || null,
      entryCode,
      allowedDays: allowedDays || null,
      allowedFrom: allowedFrom || null,
      allowedTo: allowedTo || null,
      notes: notes || null,
      status: 'ACTIVE',
    },
  });
}

async function updateDomesticHelp(id, societyId, data) {
  const item = await prisma.domesticHelp.findUnique({ where: { id } });
  if (!item || item.societyId !== societyId) {
    throw Object.assign(new Error('Domestic help not found'), { status: 404 });
  }

  const { name, phone, status, allowedDays, allowedFrom, allowedTo, notes } = data;
  const updateData = {};
  if (name !== undefined) updateData.name = name;
  if (phone !== undefined) updateData.phone = phone;
  if (status !== undefined) updateData.status = status;
  if (allowedDays !== undefined) updateData.allowedDays = allowedDays;
  if (allowedFrom !== undefined) updateData.allowedFrom = allowedFrom;
  if (allowedTo !== undefined) updateData.allowedTo = allowedTo;
  if (notes !== undefined) updateData.notes = notes;

  return prisma.domesticHelp.update({ where: { id }, data: updateData });
}

async function getDomesticHelpByCode(entryCode, societyId) {
  const item = await prisma.domesticHelp.findUnique({
    where: { entryCode },
    include: { unit: { select: { fullCode: true } } },
  });

  if (!item || item.societyId !== societyId) {
    throw Object.assign(new Error('Entry code not found'), { status: 404 });
  }

  return item;
}

async function logEntry(entryCode, loggedById, type, societyId) {
  const item = await prisma.domesticHelp.findUnique({ where: { entryCode } });
  if (!item || item.societyId !== societyId) {
    throw Object.assign(new Error('Entry code not found'), { status: 404 });
  }
  if (item.status !== 'ACTIVE') {
    throw Object.assign(new Error(`Domestic help is ${item.status}`), { status: 400 });
  }

  return prisma.domesticHelpLog.create({
    data: { domesticHelpId: item.id, unitId: item.unitId, loggedById, type },
  });
}

async function getLogs(domesticHelpId, societyId, filters = {}) {
  const item = await prisma.domesticHelp.findUnique({ where: { id: domesticHelpId } });
  if (!item || item.societyId !== societyId) {
    throw Object.assign(new Error('Domestic help not found'), { status: 404 });
  }

  const { month, page = 1, limit = 50 } = filters;
  const skip = (parseInt(page) - 1) * parseInt(limit);
  const where = { domesticHelpId };

  if (month) {
    const d = new Date(month);
    where.loggedAt = {
      gte: new Date(d.getFullYear(), d.getMonth(), 1),
      lt: new Date(d.getFullYear(), d.getMonth() + 1, 1),
    };
  }

  const [logs, total] = await Promise.all([
    prisma.domesticHelpLog.findMany({ where, skip, take: parseInt(limit), orderBy: { loggedAt: 'desc' } }),
    prisma.domesticHelpLog.count({ where }),
  ]);

  return { logs, total, page: parseInt(page), limit: parseInt(limit) };
}

async function getTodayLogs(societyId) {
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return prisma.domesticHelpLog.findMany({
    where: { loggedAt: { gte: startOfDay }, domesticHelp: { societyId } },
    include: { domesticHelp: { select: { name: true, type: true, unit: { select: { fullCode: true } } } } },
    orderBy: { loggedAt: 'desc' },
  });
}

module.exports = { listDomesticHelp, createDomesticHelp, updateDomesticHelp, getDomesticHelpByCode, logEntry, getLogs, getTodayLogs };
