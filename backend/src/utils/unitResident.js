const prisma = require('../config/db');

const RESIDENT_LIKE_ROLES = new Set(['RESIDENT', 'MEMBER']);

/** Roles that may list / browse domestic help across all units in a society. */
const DOMESTIC_HELP_SOCIETY_WIDE_ROLES = new Set(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']);

function isResidentLikeRole(role) {
  return RESIDENT_LIKE_ROLES.has((role || '').toUpperCase());
}

function canViewAllDomesticHelp(role) {
  return DOMESTIC_HELP_SOCIETY_WIDE_ROLES.has((role || '').toUpperCase());
}

async function unitIdsForUser(userId, societyId) {
  const rows = await prisma.unitResident.findMany({
    where: { userId, unit: { societyId } },
    select: { unitId: true },
  });
  return rows.map((r) => r.unitId);
}

async function userHasUnit(userId, societyId, unitId) {
  if (!unitId) return false;
  const row = await prisma.unitResident.findFirst({
    where: { userId, unitId, unit: { societyId } },
    select: { unitId: true },
  });
  return !!row;
}

module.exports = { isResidentLikeRole, canViewAllDomesticHelp, unitIdsForUser, userHasUnit };
