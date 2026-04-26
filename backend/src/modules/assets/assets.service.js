const prisma = require('../../config/db');

const ASSET_CATEGORIES = [
  'FURNITURE', 'ELECTRONICS', 'PLUMBING', 'ELECTRICAL', 'SECURITY',
  'FIRE_SAFETY', 'ELEVATOR', 'HVAC', 'GARDEN', 'SPORTS', 'CLEANING', 'OTHER',
];

async function listAssets(societyId, filters = {}) {
  const { category, status, condition, search, unitId, page = 1, limit = 50 } = filters;
  const skip = (parseInt(page) - 1) * parseInt(limit);

  const where = { societyId };
  if (category) where.category = category.toUpperCase();
  if (status) where.status = status.toUpperCase();
  if (condition) where.condition = condition.toUpperCase();
  if (unitId) where.unitId = unitId;
  if (search) {
    where.OR = [
      { name: { contains: search, mode: 'insensitive' } },
      { assetTag: { contains: search, mode: 'insensitive' } },
      { serialNumber: { contains: search, mode: 'insensitive' } },
      { location: { contains: search, mode: 'insensitive' } },
      { vendor: { contains: search, mode: 'insensitive' } },
    ];
  }

  const [assets, total] = await Promise.all([
    prisma.asset.findMany({
      where,
      include: {
        creator: { select: { id: true, name: true } },
        unit: { select: { id: true, fullCode: true, wing: true, unitNumber: true } },
        attachments: true,
        _count: { select: { maintenanceLogs: true } },
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { createdAt: 'desc' },
    }),
    prisma.asset.count({ where }),
  ]);

  return { assets, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

async function getAssetById(assetId, societyId) {
  return prisma.asset.findFirst({
    where: { id: assetId, societyId },
    include: {
      creator: { select: { id: true, name: true } },
      unit: { select: { id: true, fullCode: true, wing: true, unitNumber: true } },
      attachments: { orderBy: { uploadedAt: 'desc' } },
      maintenanceLogs: {
        include: { loggedBy: { select: { id: true, name: true } } },
        orderBy: { performedAt: 'desc' },
      },
    },
  });
}

async function createAsset(userId, societyId, data, files = []) {
  return prisma.$transaction(async (tx) => {
    const asset = await tx.asset.create({
      data: {
        societyId,
        createdById: userId,
        name: data.name,
        category: (data.category || 'OTHER').toUpperCase(),
        assetTag: data.assetTag || null,
        description: data.description || null,
        location: data.location || null,
        floor: data.floor || null,
        unitId: data.unitId || null,
        vendor: data.vendor || null,
        serialNumber: data.serialNumber || null,
        purchaseDate: data.purchaseDate ? new Date(data.purchaseDate) : null,
        purchasePrice: data.purchasePrice ? parseFloat(data.purchasePrice) : null,
        warrantyExpiry: data.warrantyExpiry ? new Date(data.warrantyExpiry) : null,
        condition: (data.condition || 'NEW').toUpperCase(),
        status: (data.status || 'ACTIVE').toUpperCase(),
      },
      include: {
        creator: { select: { id: true, name: true } },
        unit: { select: { id: true, fullCode: true, wing: true, unitNumber: true } },
        attachments: true,
      },
    });

    if (files.length > 0) {
      await tx.assetAttachment.createMany({
        data: files.map((f) => ({
          assetId: asset.id,
          docType: data.docType || 'PHOTO',
          fileName: f.originalname,
          fileType: f.mimetype,
          fileSize: f.size,
          fileUrl: `/uploads/assets/${f.filename}`,
        })),
      });
    }

    return getAssetById(asset.id, societyId);
  });
}

async function updateAsset(assetId, societyId, data, files = []) {
  const existing = await prisma.asset.findFirst({ where: { id: assetId, societyId } });
  if (!existing) {
    const err = new Error('Asset not found');
    err.status = 404;
    throw err;
  }

  return prisma.$transaction(async (tx) => {
    const updateData = {};
    const fields = [
      'name', 'category', 'assetTag', 'description', 'location', 'floor',
      'unitId', 'vendor', 'serialNumber', 'condition', 'status',
    ];
    for (const f of fields) {
      if (data[f] !== undefined) {
        updateData[f] = data[f] || null;
        if (f === 'category' || f === 'condition' || f === 'status') {
          updateData[f] = (data[f] || '').toUpperCase() || existing[f];
        }
      }
    }
    if (data.purchaseDate !== undefined) {
      updateData.purchaseDate = data.purchaseDate ? new Date(data.purchaseDate) : null;
    }
    if (data.purchasePrice !== undefined) {
      updateData.purchasePrice = data.purchasePrice ? parseFloat(data.purchasePrice) : null;
    }
    if (data.warrantyExpiry !== undefined) {
      updateData.warrantyExpiry = data.warrantyExpiry ? new Date(data.warrantyExpiry) : null;
    }

    await tx.asset.update({ where: { id: assetId }, data: updateData });

    if (files.length > 0) {
      await tx.assetAttachment.createMany({
        data: files.map((f) => ({
          assetId,
          docType: data.docType || 'PHOTO',
          fileName: f.originalname,
          fileType: f.mimetype,
          fileSize: f.size,
          fileUrl: `/uploads/assets/${f.filename}`,
        })),
      });
    }

    return getAssetById(assetId, societyId);
  });
}

async function deleteAsset(assetId, societyId) {
  const existing = await prisma.asset.findFirst({ where: { id: assetId, societyId } });
  if (!existing) {
    const err = new Error('Asset not found');
    err.status = 404;
    throw err;
  }
  await prisma.asset.delete({ where: { id: assetId } });
  return { deleted: true };
}

async function deleteAttachment(attachmentId, societyId) {
  const attachment = await prisma.assetAttachment.findFirst({
    where: { id: attachmentId },
    include: { asset: { select: { societyId: true } } },
  });
  if (!attachment || attachment.asset.societyId !== societyId) {
    const err = new Error('Attachment not found');
    err.status = 404;
    throw err;
  }
  await prisma.assetAttachment.delete({ where: { id: attachmentId } });
  return { deleted: true };
}

async function addMaintenanceLog(assetId, userId, societyId, data) {
  const asset = await prisma.asset.findFirst({ where: { id: assetId, societyId } });
  if (!asset) {
    const err = new Error('Asset not found');
    err.status = 404;
    throw err;
  }

  const log = await prisma.assetMaintenanceLog.create({
    data: {
      assetId,
      loggedById: userId,
      title: data.title,
      description: data.description || null,
      cost: data.cost ? parseFloat(data.cost) : null,
      performedAt: data.performedAt ? new Date(data.performedAt) : new Date(),
    },
    include: { loggedBy: { select: { id: true, name: true } } },
  });

  return log;
}

async function getAssetSummary(societyId) {
  const [byStatus, byCategory, totalValue] = await Promise.all([
    prisma.asset.groupBy({
      by: ['status'],
      where: { societyId },
      _count: { id: true },
    }),
    prisma.asset.groupBy({
      by: ['category'],
      where: { societyId },
      _count: { id: true },
    }),
    prisma.asset.aggregate({
      where: { societyId, status: 'ACTIVE' },
      _sum: { purchasePrice: true },
      _count: { id: true },
    }),
  ]);

  const warrantyExpiring = await prisma.asset.count({
    where: {
      societyId,
      status: 'ACTIVE',
      warrantyExpiry: {
        gte: new Date(),
        lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    },
  });

  return { byStatus, byCategory, totalValue, warrantyExpiring };
}

module.exports = {
  ASSET_CATEGORIES,
  listAssets,
  getAssetById,
  createAsset,
  updateAsset,
  deleteAsset,
  deleteAttachment,
  addMaintenanceLog,
  getAssetSummary,
};
