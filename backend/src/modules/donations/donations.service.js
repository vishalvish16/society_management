const prisma = require('../../config/db');

exports.listCampaigns = async (societyId) => {
  return prisma.donationCampaign.findMany({
    where: { societyId },
    orderBy: { createdAt: 'desc' },
    include: {
      _count: { select: { donations: true } },
      donations: { select: { amount: true } },
    },
  });
};

exports.createCampaign = async (societyId, createdById, data) => {
  const { title, description, targetAmount, startDate, endDate } = data;
  return prisma.donationCampaign.create({
    data: {
      societyId,
      createdById,
      title,
      description,
      targetAmount: targetAmount ? parseFloat(targetAmount) : null,
      startDate: new Date(startDate),
      endDate: endDate ? new Date(endDate) : null,
    },
  });
};

exports.updateCampaign = async (id, societyId, data) => {
  const { title, description, targetAmount, startDate, endDate, isActive } = data;
  return prisma.donationCampaign.update({
    where: { id },
    data: {
      ...(title !== undefined && { title }),
      ...(description !== undefined && { description }),
      ...(targetAmount !== undefined && { targetAmount: targetAmount ? parseFloat(targetAmount) : null }),
      ...(startDate !== undefined && { startDate: new Date(startDate) }),
      ...(endDate !== undefined && { endDate: endDate ? new Date(endDate) : null }),
      ...(isActive !== undefined && { isActive }),
    },
  });
};

exports.listDonations = async (societyId, { campaignId, page = 1, limit = 20 } = {}) => {
  const where = { societyId, ...(campaignId && { campaignId }) };
  const [donations, total] = await Promise.all([
    prisma.donation.findMany({
      where,
      orderBy: { paidAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
      include: {
        donor: { select: { id: true, name: true, phone: true } },
        campaign: { select: { id: true, title: true } },
      },
    }),
    prisma.donation.count({ where }),
  ]);
  return { donations, total, page, limit };
};

exports.makeDonation = async (societyId, donorId, data) => {
  const { campaignId, amount, paymentMethod, note, paidAt } = data;
  return prisma.donation.create({
    data: {
      societyId,
      donorId,
      campaignId: campaignId || null,
      amount: parseFloat(amount),
      paymentMethod,
      note,
      paidAt: paidAt ? new Date(paidAt) : new Date(),
    },
    include: {
      donor: { select: { id: true, name: true, phone: true } },
      campaign: { select: { id: true, title: true } },
    },
  });
};

exports.getSocietyBalance = async (societyId) => {
  const [totalIncome, totalDonations, totalExpenses] = await Promise.all([
    prisma.maintenanceBill.aggregate({
      where: { societyId, status: 'PAID', deletedAt: null },
      _sum: { paidAmount: true },
    }),
    prisma.donation.aggregate({
      where: { societyId },
      _sum: { amount: true },
    }),
    prisma.expense.aggregate({
      where: { societyId, status: 'APPROVED' },
      _sum: { totalAmount: true },
    }),
  ]);
  const income = Number(totalIncome._sum.paidAmount || 0) + Number(totalDonations._sum.amount || 0);
  const expenses = Number(totalExpenses._sum.totalAmount || 0);
  return { income, expenses, balance: income - expenses };
};
