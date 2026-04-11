const express = require('express');
const router = express.Router();
const deliveriesController = require('./deliveries.controller');
const { authenticateUser } = require('../../middlewares/auth.middleware');

router.get('/', authenticateUser, deliveriesController.getAllDeliveries);
router.post('/', authenticateUser, deliveriesController.createDelivery);
router.put('/:id', authenticateUser, deliveriesController.updateDelivery);
router.delete('/:id', authenticateUser, deliveriesController.deleteDelivery);

module.exports = router;
