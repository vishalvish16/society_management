const { Router } = require('express');
const billsController = require('./bills.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// Bill routes (all protected)
router.use(authMiddleware);

// Any authenticated user — returns bills for their own units
router.get('/mine', billsController.getMyBills);

// Admin-only
router.get('/defaulters', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.getDefaulters);
router.get('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.getBills);
router.post('/generate', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.bulkGenerate);

// Any authenticated user can pay their own bill (service enforces ownership)
router.post('/:id/pay', billsController.recordPayment);
router.get('/:id', billsController.getBillById);

module.exports = router;
