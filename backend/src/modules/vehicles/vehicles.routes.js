const express = require('express');
const router = express.Router();
const vehiclesController = require('./vehicles.controller');
const { authenticateUser } = require('../../middlewares/auth.middleware');

router.get('/', authenticateUser, vehiclesController.getAllVehicles);
router.post('/', authenticateUser, vehiclesController.createVehicle);
router.put('/:id', authenticateUser, vehiclesController.updateVehicle);
router.delete('/:id', authenticateUser, vehiclesController.deleteVehicle);

module.exports = router;
