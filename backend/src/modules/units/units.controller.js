const unitsService = require('./units.service');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * GET /api/v1/units
 */
async function getUnits(req, res) {
  try {
    const filters = req.query;
    const result = await unitsService.listUnits(req.user.societyId, filters);
    return sendSuccess(res, result, 'Units retrieved successfully');
  } catch (error) {
    console.error('Get units error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/units
 */
async function createUnit(req, res) {
  try {
    const { wing, floor, unitNumber, subUnit, areaSqft, notes } = req.body;

    if (!unitNumber) {
      return sendError(res, 'Unit number is required', 400);
    }

    const unit = await unitsService.createUnit(req.user.societyId, {
      wing, floor, unitNumber, subUnit, areaSqft, notes
    });

    return sendSuccess(res, unit, 'Unit created successfully', 201);
  } catch (error) {
    console.error('Create unit error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * PATCH /api/v1/units/:id
 */
async function updateUnit(req, res) {
  try {
    const { id } = req.params;
    const data = req.body;

    const updated = await unitsService.updateUnit(id, data, req.user.societyId);
    return sendSuccess(res, updated, 'Unit updated successfully');
  } catch (error) {
    console.error('Update unit error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * DELETE /api/v1/units/:id
 */
async function deleteUnit(req, res) {
  try {
    const { id } = req.params;
    await unitsService.deleteUnit(id, req.user.societyId);
    return sendSuccess(res, null, 'Unit deleted successfully');
  } catch (error) {
    console.error('Delete unit error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * POST /api/v1/units/:id/residents
 */
async function assignResident(req, res) {
  try {
    const { id: unitId } = req.params;
    const { userId, isOwner } = req.body;

    if (!userId) {
      return sendError(res, 'User ID is required', 400);
    }

    const assignment = await unitsService.assignResident(unitId, userId, !!isOwner, req.user.societyId);
    return sendSuccess(res, assignment, 'Resident assigned successfully', 201);
  } catch (error) {
    console.error('Assign resident error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

/**
 * DELETE /api/v1/units/:unitId/residents/:userId
 */
async function removeResident(req, res) {
  try {
    const { unitId, userId } = req.params;
    await unitsService.removeResident(unitId, userId, req.user.societyId);
    return sendSuccess(res, null, 'Resident removed successfully');
  } catch (error) {
    console.error('Remove resident error:', error.message);
    return sendError(res, error.message, error.status || 500);
  }
}

module.exports = {
  getUnits,
  createUnit,
  updateUnit,
  deleteUnit,
  assignResident,
  removeResident
};
