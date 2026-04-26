const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');
const { pushToRole, pushToUsers } = require('../../utils/push');

async function listExpenses(societyId, filters = {}) {
  const { category, status, page = 1, limit = 20 } = filters;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const where = { societyId };
  if (category) where.category = category.toUpperCase();
  if (status) where.status = status.toUpperCase();

  const [expenses, total] = await Promise.all([
    prisma.expense.findMany({
      where,
      include: {
        submitter: { select: { id: true, name: true } },
        approver:  { select: { id: true, name: true } },
        attachments: true,
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { expenseDate: 'desc' },
    }),
    prisma.expense.count({ where }),
  ]);

  return { expenses, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

async function submitExpense(userId, societyId, data, files = []) {
  const { category, title, description, amount, expenseDate, gstAmount = 0 } = data;

  return prisma.$transaction(async (tx) => {
    const expense = await tx.expense.create({
      data: {
        societyId,
        submittedById: userId,          // correct FK field name
        category,
        title,
        description,
        amount: Number(amount),
        gstAmount: Number(gstAmount),
        totalAmount: Number(amount) + Number(gstAmount),
        expenseDate: new Date(expenseDate),
        status: 'PENDING',
      },
    });

    if (files && files.length > 0) {
      await tx.expenseAttachment.createMany({
        data: files.map((file) => ({
          expenseId: expense.id,
          fileUrl: `expenses/${file.filename}`, // relative to uploads folder
          fileName: file.originalname || 'attachment',
          fileType: file.mimetype || 'application/octet-stream',
          fileSizeBytes: file.size || 0,
        })),
      });
    }

    const created = await tx.expense.findUnique({
      where: { id: expense.id },
      include: {
        submitter: { select: { id: true, name: true } },
        attachments: true,
      },
    });

    // Notify admins about new expense submission (exclude the submitter themselves)
    setImmediate(() => notificationsService.sendNotification(userId, societyId, {
      targetType: 'role',
      targetId: 'PRAMUKH',
      title: '💰 New Expense Submitted',
      body: `${created.submitter?.name || 'A member'}: ${title} — ₹${created.totalAmount}`,
      type: 'EXPENSE',
      route: '/expenses',
      excludeUserId: userId
    }));

    return created;
  });
}

async function updateExpense(expenseId, societyId, data, files = []) {
  const expense = await prisma.expense.findUnique({ where: { id: expenseId } });
  if (!expense) throw Object.assign(new Error('Expense not found'), { status: 404 });
  if (expense.societyId !== societyId) throw Object.assign(new Error('Access denied'), { status: 403 });
  if (expense.status !== 'PENDING') {
    throw Object.assign(new Error('Only pending expenses can be edited'), { status: 400 });
  }

  const { category, title, description, amount, expenseDate } = data;

  return prisma.$transaction(async (tx) => {
    await tx.expense.update({
      where: { id: expenseId },
      data: {
        ...(category && { category }),
        ...(title && { title }),
        ...(description !== undefined && { description }),
        ...(amount && { amount: Number(amount), totalAmount: Number(amount) }),
        ...(expenseDate && { expenseDate: new Date(expenseDate) }),
      },
    });

    if (files && files.length > 0) {
      await tx.expenseAttachment.deleteMany({ where: { expenseId } });
      await tx.expenseAttachment.createMany({
        data: files.map((file) => ({
          expenseId,
          fileUrl: `expenses/${file.filename}`,
          fileName: file.originalname || 'attachment',
          fileType: file.mimetype || 'application/octet-stream',
          fileSizeBytes: file.size || 0,
        })),
      });
    }

    return tx.expense.findUnique({
      where: { id: expenseId },
      include: {
        submitter: { select: { id: true, name: true } },
        attachments: true,
      },
    });
  });
}

async function reviewExpense(expenseId, reviewerId, status, societyId, rejectionReason = null, paymentMethod = null, referenceId = null) {
  const expense = await prisma.expense.findUnique({ where: { id: expenseId } });

  if (!expense) throw Object.assign(new Error('Expense not found'), { status: 404 });
  if (expense.societyId !== societyId) throw Object.assign(new Error('Access denied'), { status: 403 });
  if (expense.status !== 'PENDING') {
    throw Object.assign(new Error(`Expense is already ${expense.status}`), { status: 400 });
  }

  const upperStatus = status.toUpperCase();
  if (upperStatus === 'APPROVED') {
    const allowed = ['CASH', 'BANK', 'UPI', 'ONLINE', 'RAZORPAY'];
    const pm = paymentMethod ? String(paymentMethod).toUpperCase() : null;
    if (!pm || !allowed.includes(pm)) {
      throw Object.assign(new Error('paymentMethod is required to approve an expense (CASH/BANK/UPI/ONLINE/RAZORPAY)'), { status: 400 });
    }
  }

  const updated = await prisma.expense.update({
    where: { id: expenseId },
    data: {
      status: upperStatus,
      approvedById: reviewerId,
      approvedAt: upperStatus === 'APPROVED' ? new Date() : null,
      rejectionReason: upperStatus === 'REJECTED' ? rejectionReason : null,
      ...(upperStatus === 'APPROVED' ? { 
        paymentMethod: String(paymentMethod).toUpperCase(),
        referenceId: referenceId
      } : {}),
    },
  });

  // Notify submitter of approval/rejection
  if (expense.submittedById) {
    const messages = {
      APPROVED: { title: '✅ Expense Approved', body: `Your expense "${expense.title}" has been approved.` },
      REJECTED: { title: '❌ Expense Rejected', body: `Your expense "${expense.title}" was rejected.${rejectionReason ? ' Reason: ' + rejectionReason : ''}` },
    };
    const msg = messages[upperStatus];
    if (msg) {
      setImmediate(() => notificationsService.sendNotification(reviewerId, societyId, {
        targetType: 'user',
        targetId: expense.submittedById,
        title: msg.title,
        body: msg.body,
        type: 'EXPENSE',
        route: '/expenses',
        excludeUserId: reviewerId
      }));
    }
  }

  return updated;
}

async function getExpenseSummary(societyId, startDate, endDate) {
  return prisma.expense.groupBy({
    by: ['category'],
    where: {
      societyId,
      status: 'APPROVED',
      expenseDate: { gte: new Date(startDate), lte: new Date(endDate) },
    },
    _sum: { amount: true, totalAmount: true },
    _count: { id: true },
  });
}

async function getExpenseById(id, societyId) {
  return prisma.expense.findFirst({
    where: { id, societyId },
    include: { attachments: true }
  });
}

module.exports = {
  listExpenses,
  submitExpense,
  updateExpense,
  reviewExpense,
  getExpenseSummary,
  getExpenseById,
};
