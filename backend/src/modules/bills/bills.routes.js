const { Router } = require('express');
const billsController = require('./bills.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// Bill routes (all protected)
router.use(authMiddleware);

// Publicly available (to valid residents of the society)
router.get('/', billsController.getBills);
router.get('/:id', billsController.getBillById);

// Admin-only (PRAMUKH, SECRETARY)
router.post('/generate', roleGuard(['PRAMUKH', 'SECRETARY']), billsController.bulkGenerate);
router.post('/:id/pay', roleGuard(['PRAMUKH', 'SECRETARY']), billsController.recordPayment);

module.exports = router;
