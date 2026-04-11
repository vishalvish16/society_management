const prisma = require('../../config/db');

/**
 * List expenses with filters.
 */
async function listExpenses(societyId, filters = {}) {
  const { category, status, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = {
    societyId,
  };

  if (category) where.category = category;
  if (status) where.status = status;

  const [expenses, total] = await Promise.all([
    prisma.expense.findMany({
      where,
      include: {
        submitter: { select: { id: true, name: true } },
        approver: { select: { id: true, name: true } },
        attachments: true
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { expenseDate: 'desc' }
    }),
    prisma.expense.count({ where })
  ]);

  return { expenses, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

/**
 * Submit an expense (with optional attachments from multer).
 */
async function submitExpense(userId, societyId, data, files = []) {
  const { category, title, description, amount, expenseDate } = data;

  return prisma.$transaction(async (tx) => {
    const expense = await tx.expense.create({
      data: {
        societyId,
        submittedBy: userId,
        category,
        title,
        description,
        amount,
        expenseDate: new Date(expenseDate),
        status: 'PENDING'
      }
    });

    if (files && files.length > 0) {
      await tx.expenseAttachment.createMany({
        data: files.map(file => ({
          expenseId: expense.id,
          fileUrl: file.path || file.location || 'dummy-url', // Multer local storage uses .path
          fileName: file.originalname || file.name || 'attachment',
          fileType: file.mimetype || file.type || 'image/jpeg',
          fileSizeBytes: file.size || 0
        }))
      });
    }

    return tx.expense.findUnique({
      where: { id: expense.id },
      include: { attachments: true }
    });
  });
}

/**
 * Approve or reject an expense.
 */
async function reviewExpense(expenseId, reviewerId, status, societyId, rejectionReason = null) {
  const expense = await prisma.expense.findUnique({ where: { id: expenseId } });

  if (!expense) throw Object.assign(new Error('Expense not found'), { status: 404 });
  if (expense.societyId !== societyId) throw Object.assign(new Error('Access denied'), { status: 403 });

  if (expense.status !== 'PENDING') {
    throw Object.assign(new Error(`Expense is already ${expense.status.toLowerCase()}`), { status: 400 });
  }

  return prisma.expense.update({
    where: { id: expenseId },
    data: {
      status,
      approvedBy: reviewerId,
      approvedAt: status === 'APPROVED' ? new Date() : null,
      rejectionReason: status === 'REJECTED' ? rejectionReason : null
    }
  });
}

/**
 * Get expense summary.
 */
async function getExpenseSummary(societyId, startDate, endDate) {
  const stats = await prisma.expense.groupBy({
    by: ['category'],
    where: {
      societyId,
      status: 'APPROVED',
      expenseDate: {
        gte: new Date(startDate),
        lte: new Date(endDate)
      }
    },
    _sum: { amount: true }
  });

  return stats;
}

module.exports = {
  listExpenses,
  submitExpense,
  reviewExpense,
  getExpenseSummary
};
