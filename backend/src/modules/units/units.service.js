const prisma = require('../../config/db');

/**
 * List all units in a society with filtering.
 * @param {string} societyId
 * @param {{ wing?: string, floor?: number, status?: string, page?: number, limit?: number }} filters
 * @returns {Promise<{ units: object[], total: number, page: number, limit: number }>}
 */
async function listUnits(societyId, filters = {}) {
  const { wing, floor, status, page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const where = {
    societyId,
    deletedAt: null,
  };

  if (wing) where.wing = wing;
  if (floor) where.floor = parseInt(floor, 10);
  if (status) where.status = status;

  const [units, total] = await Promise.all([
    prisma.unit.findMany({
      where,
      include: {
        unitResidents: {
          include: {
            user: {
              select: { id: true, name: true, phone: true, role: true }
            }
          }
        }
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: [
        { wing: 'asc' },
        { floor: 'asc' },
        { unitNumber: 'asc' }
      ]
    }),
    prisma.unit.count({ where })
  ]);

  return { units, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

/**
 * Create a new unit.
 * @param {string} societyId
 * @param {{ wing?: string, floor?: number, unitNumber: string, subUnit?: string, areaSqft?: number, notes?: string }} data
 * @returns {Promise<object>} Created unit
 */
async function createUnit(societyId, data) {
  const { wing, floor, unitNumber, subUnit, areaSqft, notes } = data;

  // Generate fullCode
  const fullCode = `${wing || ''}${wing ? '-' : ''}${unitNumber}${subUnit || ''}`;

  // Check if fullCode already exists in this society
  const existing = await prisma.unit.findFirst({
    where: { societyId, fullCode, deletedAt: null }
  });

  if (existing) {
    throw Object.assign(new Error(`Unit ${fullCode} already exists in this society`), { status: 409 });
  }

  return prisma.unit.create({
    data: {
      societyId,
      wing,
      floor,
      unitNumber,
      subUnit,
      fullCode,
      areaSqft,
      notes,
      status: 'VACANT'
    }
  });
}

/**
 * Update unit details.
 * @param {string} unitId
 * @param {object} data
 * @param {string} societyId
 * @returns {Promise<object>} Updated unit
 */
async function updateUnit(unitId, data, societyId) {
  const unit = await prisma.unit.findUnique({ where: { id: unitId } });

  if (!unit || unit.deletedAt) {
    throw Object.assign(new Error('Unit not found'), { status: 404 });
  }

  if (unit.societyId !== societyId) {
    throw Object.assign(new Error('Cannot modify units outside your society'), { status: 403 });
  }

  // If wing/unitNumber/subUnit changes, regent fullCode and check uniqueness
  if (data.wing !== undefined || data.unitNumber !== undefined || data.subUnit !== undefined) {
    const newWing = data.wing !== undefined ? data.wing : unit.wing;
    const newUnitNumber = data.unitNumber !== undefined ? data.unitNumber : unit.unitNumber;
    const newSubUnit = data.subUnit !== undefined ? data.subUnit : unit.subUnit;
    
    data.fullCode = `${newWing || ''}${newWing ? '-' : ''}${newUnitNumber}${newSubUnit || ''}`;

    if (data.fullCode !== unit.fullCode) {
      const existing = await prisma.unit.findFirst({
        where: { societyId, fullCode: data.fullCode, deletedAt: null, NOT: { id: unitId } }
      });
      if (existing) {
        throw Object.assign(new Error(`Unit ${data.fullCode} already exists`), { status: 409 });
      }
    }
  }

  return prisma.unit.update({
    where: { id: unitId },
    data
  });
}

/**
 * Soft-delete a unit (only if vacant).
 * @param {string} unitId
 * @param {string} societyId
 * @returns {Promise<object>}
 */
async function deleteUnit(unitId, societyId) {
  const unit = await prisma.unit.findUnique({ 
    where: { id: unitId },
    include: { _count: { select: { unitResidents: true } } }
  });

  if (!unit || unit.deletedAt) {
    throw Object.assign(new Error('Unit not found'), { status: 404 });
  }

  if (unit.societyId !== societyId) {
    throw Object.assign(new Error('Cannot delete units outside your society'), { status: 403 });
  }

  if (unit._count.unitResidents > 0) {
    throw Object.assign(new Error('Cannot delete an occupied unit. Unassign residents first.'), { status: 400 });
  }

  return prisma.unit.update({
    where: { id: unitId },
    data: { deletedAt: new Date() }
  });
}

/**
 * Assign a resident to a unit.
 * @param {string} unitId
 * @param {string} userId
 * @param {boolean} isOwner
 * @param {string} societyId
 */
async function assignResident(unitId, userId, isOwner, societyId) {
  const [unit, user] = await Promise.all([
    prisma.unit.findUnique({ where: { id: unitId } }),
    prisma.user.findUnique({ where: { id: userId } })
  ]);

  if (!unit || unit.deletedAt) throw Object.assign(new Error('Unit not found'), { status: 404 });
  if (!user || user.deletedAt) throw Object.assign(new Error('User not found'), { status: 404 });

  if (unit.societyId !== societyId || user.societyId !== societyId) {
    throw Object.assign(new Error('Society mismatch for unit or user'), { status: 403 });
  }

  // Check if already assigned
  const existing = await prisma.unitResident.findFirst({
    where: { unitId, userId }
  });

  if (existing) {
    throw Object.assign(new Error('User is already assigned to this unit'), { status: 400 });
  }

  return prisma.$transaction(async (tx) => {
    const assignment = await tx.unitResident.create({
      data: { unitId, userId, isOwner, moveInDate: new Date() }
    });

    // Update unit status if it was vacant
    if (unit.status === 'VACANT') {
      await tx.unit.update({
        where: { id: unitId },
        data: { status: 'OCCUPIED' }
      });
    }

    return assignment;
  });
}

/**
 * Remove a resident from a unit.
 * @param {string} unitId
 * @param {string} userId
 * @param {string} societyId
 */
async function removeResident(unitId, userId, societyId) {
  const assignment = await prisma.unitResident.findFirst({
    where: { unitId, userId },
    include: { unit: true }
  });

  if (!assignment) {
    throw Object.assign(new Error('Resident assignment not found'), { status: 404 });
  }

  if (assignment.unit.societyId !== societyId) {
    throw Object.assign(new Error('Society mismatch'), { status: 403 });
  }

  return prisma.$transaction(async (tx) => {
    await tx.unitResident.delete({ where: { id: assignment.id } });

    // Check if any residents left
    const remainingCount = await tx.unitResident.count({
      where: { unitId }
    });

    if (remainingCount === 0) {
      await tx.unit.update({
        where: { id: unitId },
        data: { status: 'VACANT' }
      });
    }
  });
}

module.exports = {
  listUnits,
  createUnit,
  updateUnit,
  deleteUnit,
  assignResident,
  removeResident
};
