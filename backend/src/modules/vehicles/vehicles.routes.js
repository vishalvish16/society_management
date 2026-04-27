const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./vehicles.controller');

router.use(auth);

router.get('/mine', c.getMyVehicles);
router.get('/lookup/:plate', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), c.lookupByPlate);
router.get('/audit-logs', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getAllVehicleAuditLogs);
router.get('/:id/audit-logs', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getVehicleAuditLogs);
router.get('/', c.getAllVehicles);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.createVehicle);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.updateVehicle);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.deleteVehicle);

module.exports = router;
