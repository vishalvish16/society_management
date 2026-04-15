const { Router } = require('express');
const unitsController = require('./units.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const { ADMIN_ROLES } = require('../../config/constants');

const router = Router();

// Unit routes (all protected)
router.use(authMiddleware);

// Unit CRUD
router.get('/', unitsController.getUnits);
router.post('/', roleGuard(ADMIN_ROLES), checkPlanLimit('units'), unitsController.createUnit);
router.post('/bulk', roleGuard(ADMIN_ROLES), checkPlanLimit('units'), unitsController.bulkCreateUnits);
router.patch('/:id', roleGuard(ADMIN_ROLES), unitsController.updateUnit);
router.delete('/:id', roleGuard(ADMIN_ROLES), unitsController.deleteUnit);

// Resident Assignment
router.post('/:id/residents', roleGuard(ADMIN_ROLES), unitsController.assignResident);
router.delete('/:unitId/residents/:userId', roleGuard(ADMIN_ROLES), unitsController.removeResident);

module.exports = router;
