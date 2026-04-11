const { Router } = require('express');
const unitsController = require('./units.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

// Unit routes (all protected)
router.use(authMiddleware);

// Unit CRUD
router.get('/', unitsController.getUnits);
router.post('/', roleGuard(['PRAMUKH', 'SECRETARY']), checkPlanLimit('units'), unitsController.createUnit);
router.patch('/:id', roleGuard(['PRAMUKH', 'SECRETARY']), unitsController.updateUnit);
router.delete('/:id', roleGuard(['PRAMUKH', 'SECRETARY']), unitsController.deleteUnit);

// Resident Assignment
router.post('/:id/residents', roleGuard(['PRAMUKH', 'SECRETARY']), unitsController.assignResident);
router.delete('/:unitId/residents/:userId', roleGuard(['PRAMUKH', 'SECRETARY']), unitsController.removeResident);

module.exports = router;
