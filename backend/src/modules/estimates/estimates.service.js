const prisma = require('../../config/db');
const { computeSubscriptionAmount, normalizeDuration } = require('../../config/planConfig');

const ESTIMATE_SELECT = {
  id: true,
  estimateNumber: true,
  societyName: true,
  contactPerson: true,
  contactPhone: true,
  contactEmail: true,
  city: true,
  unitCount: true,
  duration: true,
  pricePerUnit: true,
  subtotal: true,
  discountPercent: true,
  discountAmount: true,
  totalAmount: true,
  requirements: true,
  notes: true,
  status: true,
  closeReason: true,
  sentAt: true,
  acceptedAt: true,
  linkedSocietyId: true,
  createdById: true,
  createdAt: true,
  updatedAt: true,
  plan: { select: { id: true, name: true, displayName: true } },
};

/** Auto-generate estimate number: EST-YYYY-NNNN */
async function nextEstimateNumber() {
  const year = new Date().getFullYear();
  const prefix = `EST-${year}-`;
  const last = await prisma.estimate.findFirst({
    where: { estimateNumber: { startsWith: prefix } },
    orderBy: { createdAt: 'desc' },
    select: { estimateNumber: true },
  });
  const seq = last ? parseInt(last.estimateNumber.split('-')[2] || '0', 10) + 1 : 1;
  return `${prefix}${String(seq).padStart(4, '0')}`;
}

/**
 * List estimates with optional filters.
 */
async function listEstimates({ status, search, page = 1, limit = 20 } = {}) {
  const where = {};
  if (status) where.status = status;
  if (search) {
    where.OR = [
      { societyName: { contains: search, mode: 'insensitive' } },
      { contactPerson: { contains: search, mode: 'insensitive' } },
      { contactEmail: { contains: search, mode: 'insensitive' } },
      { estimateNumber: { contains: search, mode: 'insensitive' } },
    ];
  }

  const [total, estimates] = await Promise.all([
    prisma.estimate.count({ where }),
    prisma.estimate.findMany({
      where,
      select: ESTIMATE_SELECT,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    }),
  ]);

  return { estimates, total, page, limit, totalPages: Math.ceil(total / limit) };
}

async function getEstimateById(id) {
  return prisma.estimate.findUnique({ where: { id }, select: ESTIMATE_SELECT });
}

/**
 * Create a new estimate. Pricing is computed from the plan's tiers + duration.
 */
async function createEstimate({ planId, unitCount, duration, discountPercent = 0, createdById, ...rest }) {
  const plan = await prisma.plan.findUnique({
    where: { id: planId },
    select: {
      id: true, name: true, pricePerUnit: true,
      pricingTiers: { select: { minUnits: true, maxUnits: true, pricePerUnit: true }, orderBy: { sortOrder: 'asc' } },
    },
  });
  if (!plan) throw Object.assign(new Error('Plan not found'), { status: 400 });

  const dur = normalizeDuration(duration);
  const units = Math.max(parseInt(unitCount, 10) || 0, 1);
  const disc = Math.max(0, Math.min(parseFloat(discountPercent) || 0, 100));

  const pricing = computeSubscriptionAmount(plan, units, dur, disc);
  const subtotal = pricing.amount / (1 - (pricing.totalDiscountPercent / 100) || 1);
  const discountAmount = subtotal - pricing.amount;

  const estimateNumber = await nextEstimateNumber();

  return prisma.estimate.create({
    data: {
      estimateNumber,
      planId,
      unitCount: units,
      duration: dur,
      pricePerUnit: pricing.perUnit,
      subtotal: Math.round(subtotal * 100) / 100,
      discountPercent: disc,
      discountAmount: Math.round(discountAmount * 100) / 100,
      totalAmount: pricing.amount,
      status: 'DRAFT',
      createdById: createdById || null,
      ...rest,
    },
    select: ESTIMATE_SELECT,
  });
}

/**
 * Update editable fields (only DRAFT estimates can be fully edited).
 */
async function updateEstimate(id, data) {
  const estimate = await prisma.estimate.findUnique({ where: { id }, select: { status: true, planId: true } });
  if (!estimate) throw Object.assign(new Error('Estimate not found'), { status: 404 });

  const allowed = ['societyName', 'contactPerson', 'contactPhone', 'contactEmail', 'city',
    'notes', 'requirements', 'discountPercent'];

  // Non-draft: only notes/requirements can be edited
  const editable = estimate.status === 'DRAFT'
    ? [...allowed, 'unitCount', 'planId', 'duration']
    : ['notes', 'requirements'];

  const updateData = {};
  for (const key of editable) {
    if (data[key] !== undefined) updateData[key] = data[key];
  }

  // Recompute pricing if plan/units/duration/discount changed
  if (estimate.status === 'DRAFT' && (data.planId || data.unitCount || data.duration || data.discountPercent !== undefined)) {
    const planId = data.planId || estimate.planId;
    const plan = await prisma.plan.findUnique({
      where: { id: planId },
      select: {
        id: true, pricePerUnit: true,
        pricingTiers: { select: { minUnits: true, maxUnits: true, pricePerUnit: true }, orderBy: { sortOrder: 'asc' } },
      },
    });
    const current = await prisma.estimate.findUnique({ where: { id }, select: { unitCount: true, duration: true, discountPercent: true } });
    const units = parseInt(data.unitCount ?? current.unitCount, 10);
    const dur = normalizeDuration(data.duration ?? current.duration);
    const disc = parseFloat(data.discountPercent ?? current.discountPercent) || 0;

    const pricing = computeSubscriptionAmount(plan, units, dur, disc);
    const subtotal = pricing.unitCount * pricing.perUnit * pricing.months;
    const discountAmount = subtotal - pricing.amount;

    updateData.pricePerUnit = pricing.perUnit;
    updateData.subtotal = Math.round(subtotal * 100) / 100;
    updateData.discountPercent = disc;
    updateData.discountAmount = Math.round(discountAmount * 100) / 100;
    updateData.totalAmount = pricing.amount;
    if (data.planId) updateData.planId = data.planId;
    if (data.unitCount) updateData.unitCount = units;
    if (data.duration) updateData.duration = dur;
  }

  return prisma.estimate.update({ where: { id }, data: updateData, select: ESTIMATE_SELECT });
}

/** Mark as SENT (records sentAt timestamp). */
async function sendEstimate(id) {
  const e = await prisma.estimate.findUnique({ where: { id }, select: { status: true } });
  if (!e) throw Object.assign(new Error('Estimate not found'), { status: 404 });
  if (!['DRAFT', 'SENT'].includes(e.status)) {
    throw Object.assign(new Error(`Cannot send estimate in status: ${e.status}`), { status: 409 });
  }
  return prisma.estimate.update({
    where: { id },
    data: { status: 'SENT', sentAt: new Date() },
    select: ESTIMATE_SELECT,
  });
}

/** Mark as ACCEPTED. */
async function acceptEstimate(id) {
  const e = await prisma.estimate.findUnique({ where: { id }, select: { status: true } });
  if (!e) throw Object.assign(new Error('Estimate not found'), { status: 404 });
  if (e.status !== 'SENT') throw Object.assign(new Error('Only SENT estimates can be accepted'), { status: 409 });
  return prisma.estimate.update({
    where: { id },
    data: { status: 'ACCEPTED', acceptedAt: new Date() },
    select: ESTIMATE_SELECT,
  });
}

/**
 * Close/reject an estimate with a mandatory reason.
 * @param {'REJECTED'|'CLOSED'} targetStatus
 */
async function closeEstimate(id, { closeReason, targetStatus = 'CLOSED' }) {
  if (!closeReason || !closeReason.trim()) {
    throw Object.assign(new Error('A close reason is required'), { status: 400 });
  }
  const e = await prisma.estimate.findUnique({ where: { id }, select: { status: true } });
  if (!e) throw Object.assign(new Error('Estimate not found'), { status: 404 });
  if (['CLOSED', 'REJECTED'].includes(e.status)) {
    throw Object.assign(new Error('Estimate is already closed/rejected'), { status: 409 });
  }
  const finalStatus = ['REJECTED', 'CLOSED'].includes(targetStatus) ? targetStatus : 'CLOSED';
  return prisma.estimate.update({
    where: { id },
    data: { status: finalStatus, closeReason: closeReason.trim() },
    select: ESTIMATE_SELECT,
  });
}

/**
 * Link estimate to a society created from it.
 * Called from society creation flow.
 */
async function linkEstimateToSociety(estimateId, societyId) {
  return prisma.estimate.update({
    where: { id: estimateId },
    data: { linkedSocietyId: societyId, status: 'ACCEPTED', acceptedAt: new Date() },
    select: { id: true, estimateNumber: true, linkedSocietyId: true, status: true },
  });
}

/** Get accepted estimates not yet linked to a society (for society creation picker). */
async function getAcceptedUnlinked() {
  return prisma.estimate.findMany({
    where: { status: 'ACCEPTED', linkedSocietyId: null },
    select: {
      id: true, estimateNumber: true, societyName: true, contactPerson: true,
      contactPhone: true, contactEmail: true, city: true, unitCount: true,
      duration: true, totalAmount: true, discountPercent: true,
      plan: { select: { id: true, name: true, displayName: true } },
    },
    orderBy: { acceptedAt: 'desc' },
  });
}

module.exports = {
  listEstimates, getEstimateById, createEstimate, updateEstimate,
  sendEstimate, acceptEstimate, closeEstimate, linkEstimateToSociety, getAcceptedUnlinked,
};
