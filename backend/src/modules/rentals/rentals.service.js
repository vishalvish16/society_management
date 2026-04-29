const prisma = require('../../config/db');

const INCLUDE_ALL = {
  unit: { select: { id: true, fullCode: true, wing: true, floor: true, unitNumber: true } },
  ownerUser: { select: { id: true, name: true, phone: true } },
  tenantUser: { select: { id: true, name: true, phone: true } },
  documents: {
    select: { id: true, docType: true, fileName: true, fileType: true, fileSize: true, fileUrl: true, uploadedAt: true },
    orderBy: { uploadedAt: 'asc' },
  },
  members: {
    select: { id: true, name: true, relation: true, age: true, gender: true, phone: true, isAdult: true, aadhaarNumber: true },
    orderBy: { createdAt: 'asc' },
  },
};

/**
 * Recompute the occupancyType for a unit based on active rentals and owner residents.
 * - No active rentals -> OWNER_OCCUPIED (or VACANT if no residents)
 * - Has active rentals AND has owner residents -> PARTIALLY_RENTED
 * - Has active rentals but NO owner residents -> RENTED / LEASED
 */
async function _recomputeOccupancy(tx, unitId) {
  const [activeRentals, ownerResidents] = await Promise.all([
    tx.rentalRecord.findMany({
      where: { unitId, isActive: true },
      select: { agreementType: true },
    }),
    tx.unitResident.count({
      // Only count owners who are actually staying in the unit.
      // A property owner may exist but not live in the society.
      where: { unitId, isOwner: true, isStaying: true },
    }),
  ]);

  let occupancy;
  if (activeRentals.length === 0) {
    occupancy = 'OWNER_OCCUPIED';
  } else if (ownerResidents > 0) {
    occupancy = 'PARTIALLY_RENTED';
  } else {
    const hasLease = activeRentals.some((r) => r.agreementType === 'LEASE');
    occupancy = hasLease ? 'LEASED' : 'RENTED';
  }

  await tx.unit.update({ where: { id: unitId }, data: { occupancyType: occupancy } });
}

async function listRentals(societyId, filters = {}) {
  const { unitId, isActive, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = { societyId };
  if (unitId) where.unitId = unitId;
  if (isActive !== undefined) where.isActive = isActive === 'true' || isActive === true;

  const [records, total] = await Promise.all([
    prisma.rentalRecord.findMany({
      where,
      include: INCLUDE_ALL,
      skip,
      take: parseInt(limit, 10),
      orderBy: { createdAt: 'desc' },
    }),
    prisma.rentalRecord.count({ where }),
  ]);

  return { records, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

async function getRental(id, societyId) {
  const record = await prisma.rentalRecord.findUnique({
    where: { id },
    include: INCLUDE_ALL,
  });

  if (!record || record.societyId !== societyId) {
    throw Object.assign(new Error('Rental record not found'), { status: 404 });
  }

  return record;
}

async function createRental(societyId, data, fileData = [], membersData = []) {
  const {
    unitId, portion, tenantName, tenantPhone, tenantEmail, tenantAadhaar,
    membersCount, ownerUserId, tenantUserId, agreementType,
    rentAmount, securityDeposit, agreementStartDate, agreementEndDate,
    policeVerification, nokName, nokPhone, notes,
  } = data;

  const unit = await prisma.unit.findUnique({ where: { id: unitId } });
  if (!unit || unit.deletedAt || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found in this society'), { status: 404 });
  }

  if (portion) {
    const duplicate = await prisma.rentalRecord.findFirst({
      where: { unitId, portion, isActive: true },
    });
    if (duplicate) {
      throw Object.assign(
        new Error(`Portion "${portion}" already has an active rental. End it first or use a different portion name.`),
        { status: 409 },
      );
    }
  }

  const actualCount = membersData.length > 0 ? membersData.length : (parseInt(membersCount, 10) || 1);

  return prisma.$transaction(async (tx) => {
    const record = await tx.rentalRecord.create({
      data: {
        unitId,
        societyId,
        portion: portion || null,
        tenantName,
        tenantPhone,
        tenantEmail: tenantEmail || null,
        tenantAadhaar: tenantAadhaar || null,
        membersCount: actualCount,
        ownerUserId: ownerUserId || null,
        tenantUserId: tenantUserId || null,
        agreementType: agreementType || 'RENT',
        rentAmount: rentAmount || null,
        securityDeposit: securityDeposit || null,
        agreementStartDate: new Date(agreementStartDate),
        agreementEndDate: agreementEndDate ? new Date(agreementEndDate) : null,
        policeVerification: policeVerification === true || policeVerification === 'true',
        nokName: nokName || null,
        nokPhone: nokPhone || null,
        notes: notes || null,
        documents: fileData.length > 0 ? { create: fileData } : undefined,
        members: membersData.length > 0 ? { create: membersData } : undefined,
      },
      include: INCLUDE_ALL,
    });

    await _recomputeOccupancy(tx, unitId);
    return record;
  });
}

async function updateRental(id, societyId, data, fileData = []) {
  const record = await prisma.rentalRecord.findUnique({ where: { id } });
  if (!record || record.societyId !== societyId) {
    throw Object.assign(new Error('Rental record not found'), { status: 404 });
  }

  const _toNullIfEmpty = (v) => {
    if (v === undefined) return undefined;
    if (v === null) return null;
    if (typeof v === 'string' && v.trim() === '') return null;
    return v;
  };

  const _toDecimalOrNull = (v) => {
    const normalized = _toNullIfEmpty(v);
    if (normalized === undefined) return undefined;
    if (normalized === null) return null;
    // Prisma Decimal accepts number or decimal string. Keep strings as-is.
    if (typeof normalized === 'number') return normalized;
    if (typeof normalized === 'string') return normalized.trim();
    return normalized;
  };

  const updateData = {};
  const fields = [
    'portion', 'tenantName', 'tenantPhone', 'tenantEmail', 'tenantAadhaar',
    'membersCount', 'ownerUserId', 'tenantUserId', 'agreementType',
    'rentAmount', 'securityDeposit',
    'nokName', 'nokPhone', 'notes',
  ];

  for (const f of fields) {
    if (data[f] === undefined) continue;

    // Normalize empty strings coming from clients.
    if (f === 'rentAmount' || f === 'securityDeposit') {
      updateData[f] = _toDecimalOrNull(data[f]);
      continue;
    }

    // Nullable string/id fields should become null when empty.
    if (['portion', 'tenantEmail', 'tenantAadhaar', 'ownerUserId', 'tenantUserId', 'nokName', 'nokPhone', 'notes'].includes(f)) {
      updateData[f] = _toNullIfEmpty(data[f]);
      continue;
    }

    updateData[f] = data[f];
  }
  if (data.policeVerification !== undefined) {
    updateData.policeVerification = data.policeVerification === true || data.policeVerification === 'true';
  }
  if (data.membersCount !== undefined) {
    updateData.membersCount = parseInt(data.membersCount, 10) || 1;
  }
  if (data.agreementStartDate !== undefined) {
    const v = _toNullIfEmpty(data.agreementStartDate);
    if (v) updateData.agreementStartDate = new Date(v);
  }
  if (data.agreementEndDate !== undefined) {
    const v = _toNullIfEmpty(data.agreementEndDate);
    updateData.agreementEndDate = v ? new Date(v) : null;
  }

  return prisma.$transaction(async (tx) => {
    if (fileData.length > 0) {
      await tx.rentalDocument.createMany({
        data: fileData.map((f) => ({ ...f, rentalRecordId: id })),
      });
    }

    const updated = await tx.rentalRecord.update({
      where: { id },
      data: updateData,
      include: INCLUDE_ALL,
    });

    await _recomputeOccupancy(tx, record.unitId);
    return updated;
  });
}

async function endRental(id, societyId) {
  const record = await prisma.rentalRecord.findUnique({ where: { id } });
  if (!record || record.societyId !== societyId) {
    throw Object.assign(new Error('Rental record not found'), { status: 404 });
  }

  if (!record.isActive) {
    throw Object.assign(new Error('This rental is already ended'), { status: 400 });
  }

  return prisma.$transaction(async (tx) => {
    const updated = await tx.rentalRecord.update({
      where: { id },
      data: { isActive: false, agreementEndDate: new Date() },
    });

    await _recomputeOccupancy(tx, record.unitId);
    return updated;
  });
}

async function deleteRental(id, societyId) {
  const record = await prisma.rentalRecord.findUnique({ where: { id } });
  if (!record || record.societyId !== societyId) {
    throw Object.assign(new Error('Rental record not found'), { status: 404 });
  }

  return prisma.$transaction(async (tx) => {
    await tx.rentalRecord.delete({ where: { id } });

    if (record.isActive) {
      await _recomputeOccupancy(tx, record.unitId);
    }
  });
}

async function deleteDocument(rentalId, docId, societyId) {
  const record = await prisma.rentalRecord.findUnique({ where: { id: rentalId } });
  if (!record || record.societyId !== societyId) {
    throw Object.assign(new Error('Rental record not found'), { status: 404 });
  }

  const doc = await prisma.rentalDocument.findUnique({ where: { id: docId } });
  if (!doc || doc.rentalRecordId !== rentalId) {
    throw Object.assign(new Error('Document not found'), { status: 404 });
  }

  await prisma.rentalDocument.delete({ where: { id: docId } });
}

async function syncMembers(rentalId, societyId, membersData) {
  const record = await prisma.rentalRecord.findUnique({ where: { id: rentalId } });
  if (!record || record.societyId !== societyId) {
    throw Object.assign(new Error('Rental record not found'), { status: 404 });
  }

  return prisma.$transaction(async (tx) => {
    await tx.rentalMember.deleteMany({ where: { rentalRecordId: rentalId } });

    if (membersData.length > 0) {
      await tx.rentalMember.createMany({
        data: membersData.map((m) => ({
          rentalRecordId: rentalId,
          name: m.name,
          relation: m.relation || 'OTHER',
          age: m.age ? parseInt(m.age, 10) : null,
          gender: m.gender || null,
          phone: m.phone || null,
          isAdult: m.isAdult !== false && m.isAdult !== 'false',
          aadhaarNumber: m.aadhaarNumber || null,
        })),
      });
    }

    const updated = await tx.rentalRecord.update({
      where: { id: rentalId },
      data: { membersCount: membersData.length || 1 },
      include: INCLUDE_ALL,
    });

    return updated;
  });
}

module.exports = { listRentals, getRental, createRental, updateRental, endRental, deleteRental, deleteDocument, syncMembers };
