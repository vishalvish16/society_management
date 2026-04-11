const prisma = require('../../config/db');

const PAYMENT_SELECT = {
  id: true,
  amount: true,
  periodStart: true,
  periodEnd: true,
  paymentMethod: true,
  reference: true,
  notes: true,
  createdAt: true,
  society: { select: { id: true, name: true, status: true } },
  planId: true,
};

/**
 * List subscription payments with filters.
 * @param {{ page: number, limit: number, societyId?: string }} params
 */
async function listSubscriptions({ page = 1, limit = 20, societyId }) {
  const where = {};
  if (societyId) where.societyId = societyId;

  const [subscriptions, total] = await Promise.all([
    prisma.subscriptionPayment.findMany({
      where,
      select: PAYMENT_SELECT,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.subscriptionPayment.count({ where }),
  ]);

  return { subscriptions, total, page, limit, totalPages: Math.ceil(total / limit) };
}

/**
 * Get a subscription payment by ID.
 * @param {string} id
 */
async function getSubscriptionById(id) {
  return prisma.subscriptionPayment.findUnique({
    where: { id },
    select: PAYMENT_SELECT,
  });
}

/**
 * Assign a plan to a society and record payment.
 * @param {{ societyId: string, planName: string, amount: number, paymentMethod?: string, reference?: string, billingCycle?: string, notes?: string, recordedById?: string }} data
 */
async function assignPlan({ societyId, planName, amount, paymentMethod, reference, billingCycle, notes, recordedById }) {
  return prisma.$transaction(async (tx) => {
    const plan = await tx.plan.findUnique({ where: { name: planName } });
    if (!plan) throw Object.assign(new Error('Plan not found'), { status: 400 });
    if (!plan.isActive) throw Object.assign(new Error('Plan is not active'), { status: 400 });

    const society = await tx.society.findUnique({ where: { id: societyId }, select: { id: true } });
    if (!society) throw Object.assign(new Error('Society not found'), { status: 404 });

    const now = new Date();
    const cycle = billingCycle || 'monthly';
    let periodEnd;
    if (cycle === 'monthly') periodEnd = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());
    else if (cycle === 'quarterly') periodEnd = new Date(now.getFullYear(), now.getMonth() + 3, now.getDate());
    else periodEnd = new Date(now.getFullYear() + 1, now.getMonth(), now.getDate());

    // Update society plan
    await tx.society.update({
      where: { id: societyId },
      data: { planId: plan.id, planStartDate: now, planRenewalDate: periodEnd, status: 'active' },
    });

    // Record payment
    return tx.subscriptionPayment.create({
      data: {
        societyId,
        planId: plan.id,
        amount: amount !== undefined ? amount : plan.priceMonthly,
        periodStart: now,
        periodEnd,
        paymentMethod: paymentMethod || null,
        reference: reference || null,
        notes: notes || null,
        recordedById: recordedById || null,
      },
      select: PAYMENT_SELECT,
    });
  });
}

/**
 * Renew current society plan by one billing cycle.
 * @param {string} societyId
 * @param {{ amount?: number, paymentMethod?: string, reference?: string, billingCycle?: string, recordedById?: string }} opts
 */
async function renewSubscription(societyId, { amount, paymentMethod, reference, billingCycle, recordedById } = {}) {
  const society = await prisma.society.findUnique({
    where: { id: societyId },
    select: { id: true, planId: true, planRenewalDate: true, plan: { select: { priceMonthly: true } } },
  });
  if (!society) throw Object.assign(new Error('Society not found'), { status: 404 });

  const base = society.planRenewalDate ? new Date(society.planRenewalDate) : new Date();
  const cycle = billingCycle || 'monthly';
  let newEnd;
  if (cycle === 'monthly') newEnd = new Date(base.getFullYear(), base.getMonth() + 1, base.getDate());
  else if (cycle === 'quarterly') newEnd = new Date(base.getFullYear(), base.getMonth() + 3, base.getDate());
  else newEnd = new Date(base.getFullYear() + 1, base.getMonth(), base.getDate());

  const now = new Date();

  await prisma.society.update({
    where: { id: societyId },
    data: { planRenewalDate: newEnd, status: 'active' },
  });

  return prisma.subscriptionPayment.create({
    data: {
      societyId,
      planId: society.planId,
      amount: amount !== undefined ? amount : society.plan.priceMonthly,
      periodStart: base,
      periodEnd: newEnd,
      paymentMethod: paymentMethod || null,
      reference: reference || null,
      recordedById: recordedById || null,
    },
    select: PAYMENT_SELECT,
  });
}

module.exports = { listSubscriptions, getSubscriptionById, assignPlan, renewSubscription };
