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
  plan: { select: { name: true, displayName: true } },
  planId: true,
};

/**
 * List current subscriptions (societies + latest payment).
 * Includes TRIAL societies that have no payment yet.
 * @param {{ page: number, limit: number, societyId?: string, status?: string }} params
 */
async function listSubscriptions({ page = 1, limit = 20, societyId, status }) {
  const societiesWhere = {};
  if (societyId) societiesWhere.id = societyId;

  // Fetch societies and their latest payment (if any).
  const societies = await prisma.society.findMany({
    where: societiesWhere,
    select: {
      id: true,
      name: true,
      status: true,
      planStartDate: true,
      planRenewalDate: true,
      settings: true,
      plan: { select: { id: true, name: true, displayName: true } },
      subscriptionPayments: {
        take: 1,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          amount: true,
          periodStart: true,
          periodEnd: true,
          paymentMethod: true,
          reference: true,
          notes: true,
          createdAt: true,
        },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  const now = new Date();
  const mapped = societies.map((s) => {
    const latest = s.subscriptionPayments?.[0] || null;
    const settings = s.settings || {};
    const trialEnabled = settings && typeof settings === 'object' ? settings.trialEnabled === true : false;

    let computedStatus = 'ACTIVE';
    if (s.status !== 'ACTIVE') computedStatus = 'CANCELLED';
    else if (!latest && trialEnabled && s.planRenewalDate && now < new Date(s.planRenewalDate)) computedStatus = 'TRIAL';
    else if (s.planRenewalDate && now > new Date(s.planRenewalDate)) computedStatus = 'EXPIRED';

    return {
      id: s.id, // societyId (used by renew endpoint)
      status: computedStatus,
      amount: latest ? latest.amount : 0,
      periodStart: latest ? latest.periodStart : s.planStartDate,
      periodEnd: latest ? latest.periodEnd : s.planRenewalDate,
      paymentMethod: latest ? latest.paymentMethod : null,
      reference: latest ? latest.reference : null,
      notes: latest ? latest.notes : (computedStatus === 'TRIAL' ? 'Trial period' : null),
      createdAt: latest ? latest.createdAt : s.planStartDate,
      society: { id: s.id, name: s.name, status: s.status },
      plan: s.plan,
      planId: s.plan?.id,
      autoRenew: false,
      billingCycle: null,
      _latestPaymentId: latest ? latest.id : null,
    };
  });

  const filtered = status
    ? mapped.filter((m) => String(m.status).toUpperCase() === String(status).toUpperCase())
    : mapped;

  const total = filtered.length;
  const start = (page - 1) * limit;
  const subs = filtered.slice(start, start + limit);

  return { subscriptions: subs, total, page, limit, totalPages: Math.ceil(total / limit) };
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
      data: { planId: plan.id, planStartDate: now, planRenewalDate: periodEnd, status: 'ACTIVE' },
    });

    // Record payment
    return tx.subscriptionPayment.create({
      data: {
        societyId,
        planId: plan.id,
        amount: amount !== undefined ? amount : (cycle === 'yearly' ? plan.priceYearly : plan.priceMonthly),
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
 * @param {{ amount?: number, paymentMethod?: string, reference?: string, billingCycle?: string, planName?: string, periods?: number, discountPercent?: number, notes?: string, recordedById?: string }} opts
 */
async function renewSubscription(
  societyId,
  { amount, paymentMethod, reference, billingCycle, planName, periods, discountPercent, notes, startDate, recordedById } = {},
) {
  const society = await prisma.society.findUnique({
    where: { id: societyId },
    select: {
      id: true,
      planId: true,
      planRenewalDate: true,
      planStartDate: true,
      status: true,
      plan: { select: { id: true, name: true, priceMonthly: true, priceYearly: true } },
    },
  });
  if (!society) throw Object.assign(new Error('Society not found'), { status: 404 });

  const cycle = (billingCycle || 'monthly').toLowerCase();
  const count = Math.max(parseInt(periods || 1, 10) || 1, 1);

  const addMonths = (date, months) => {
    const d = new Date(date);
    return new Date(d.getFullYear(), d.getMonth() + months, d.getDate());
  };

  let monthsToAdd = 1;
  if (cycle === 'quarterly') monthsToAdd = 3;
  else if (cycle === 'yearly') monthsToAdd = 12;

  const now = new Date();
  let base;
  if (startDate) {
    const parsed = new Date(startDate);
    if (Number.isNaN(parsed.getTime())) {
      throw Object.assign(new Error('Invalid startDate'), { status: 400 });
    }
    base = parsed;
  } else {
    const baseRaw = society.planRenewalDate ? new Date(society.planRenewalDate) : now;
    base = baseRaw < now ? now : baseRaw; // if expired, renew from today
  }
  const newEnd = addMonths(base, monthsToAdd * count);

  // plan switch (optional)
  let plan = society.plan;
  if (planName) {
    const nextPlan = await prisma.plan.findUnique({ where: { name: String(planName).toLowerCase() } });
    if (!nextPlan) throw Object.assign(new Error('Plan not found'), { status: 400 });
    if (!nextPlan.isActive) throw Object.assign(new Error('Plan is not active'), { status: 400 });
    plan = nextPlan;
  }

  // compute amount if not provided
  let computedAmount;
  if (amount !== undefined && amount !== null && amount !== '') {
    computedAmount = parseFloat(amount);
  } else {
    let baseTotal = 0;
    if (cycle === 'yearly') baseTotal = parseFloat(plan.priceYearly) * count;
    else if (cycle === 'quarterly') baseTotal = parseFloat(plan.priceMonthly) * 3 * count;
    else baseTotal = parseFloat(plan.priceMonthly) * count;

    const disc = discountPercent !== undefined && discountPercent !== null && discountPercent !== ''
      ? Math.max(Math.min(parseFloat(discountPercent), 100), 0)
      : 0;
    computedAmount = baseTotal * (1 - disc / 100);
  }

  computedAmount = Math.round(computedAmount * 100) / 100;

  // update society + record payment
  const result = await prisma.$transaction(async (tx) => {
    await tx.society.update({
      where: { id: societyId },
      data: {
        planId: plan.id,
        planStartDate: base,
        planRenewalDate: newEnd,
        status: 'ACTIVE',
      },
    });

    return tx.subscriptionPayment.create({
      data: {
        societyId,
        planId: plan.id,
        amount: computedAmount,
        periodStart: base,
        periodEnd: newEnd,
        paymentMethod: paymentMethod || null,
        reference: reference || null,
        notes:
          notes ||
          `Renewed (${cycle}) x${count}${discountPercent ? `, discount ${discountPercent}%` : ''}`,
        recordedById: recordedById || null,
      },
      select: PAYMENT_SELECT,
    });
  });

  return result;
}

module.exports = { listSubscriptions, getSubscriptionById, assignPlan, renewSubscription };

/**
 * Date-wise subscription payment report.
 * @param {{
 *  from?: string,
 *  to?: string,
 *  planName?: string,
 *  paymentMethod?: string,
 *  search?: string,
 *  orderBy?: string,
 *  orderDir?: string,
 *  page: number,
 *  limit: number
 * }} params
 */
async function getSubscriptionReport({
  from,
  to,
  planName,
  paymentMethod,
  search,
  orderBy = 'createdAt',
  orderDir = 'desc',
  page = 1,
  limit = 50,
}) {
  const where = {};

  if (from || to) {
    where.createdAt = {};
    if (from) {
      const d = new Date(from);
      if (Number.isNaN(d.getTime())) throw Object.assign(new Error('Invalid from date'), { status: 400 });
      where.createdAt.gte = d;
    }
    if (to) {
      const d = new Date(to);
      if (Number.isNaN(d.getTime())) throw Object.assign(new Error('Invalid to date'), { status: 400 });
      where.createdAt.lte = d;
    }
  }

  if (paymentMethod) {
    where.paymentMethod = String(paymentMethod).toUpperCase();
  }

  if (planName) {
    where.plan = { name: String(planName).toLowerCase() };
  }

  if (search) {
    where.society = { name: { contains: String(search), mode: 'insensitive' } };
  }

  const dir = String(orderDir).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const safeOrderBy = String(orderBy);

  let orderByClause = { createdAt: dir };
  if (safeOrderBy === 'amount') orderByClause = { amount: dir };
  if (safeOrderBy === 'periodStart') orderByClause = { periodStart: dir };
  if (safeOrderBy === 'periodEnd') orderByClause = { periodEnd: dir };
  if (safeOrderBy === 'societyName') orderByClause = { society: { name: dir } };
  if (safeOrderBy === 'planName') orderByClause = { plan: { name: dir } };

  const [rows, total] = await Promise.all([
    prisma.subscriptionPayment.findMany({
      where,
      select: {
        id: true,
        amount: true,
        periodStart: true,
        periodEnd: true,
        paymentMethod: true,
        reference: true,
        notes: true,
        createdAt: true,
        society: { select: { id: true, name: true } },
        plan: { select: { name: true, displayName: true } },
      },
      orderBy: orderByClause,
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.subscriptionPayment.count({ where }),
  ]);

  return { rows, total, page, limit, totalPages: Math.ceil(total / limit) };
}

module.exports.getSubscriptionReport = getSubscriptionReport;
