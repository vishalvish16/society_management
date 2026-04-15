const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./vehicles.controller');

router.use(auth);

router.get('/mine', c.getMyVehicles);
router.get('/lookup/:plate', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), c.lookupByPlate);
router.get('/', c.getAllVehicles);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.createVehicle);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT']), c.updateVehicle);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteVehicle);

module.exports = router;
