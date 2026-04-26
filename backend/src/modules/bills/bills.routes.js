const { Router } = require('express');
const billsController = require('./bills.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');

const router = Router();

// Bill routes (all protected)
router.use(authMiddleware);

// Any authenticated user — returns bills for their own units
router.get('/mine', billsController.getMyBills);

// Admin-only
router.get('/audit-logs', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.getAllBillAuditLogs);
router.get('/defaulters', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.getDefaulters);

// Scheduled bill generation (Admin-only)
router.get(
  '/schedules',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']),
  checkPlanLimit('bill_schedules'),
  billsController.listSchedules
);
router.post(
  '/schedules',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']),
  checkPlanLimit('bill_schedules'),
  billsController.upsertSchedule
);

router.get('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.getBills);
router.post('/generate', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.bulkGenerate);
router.post('/pay-advance', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT']), billsController.payAdvance);
router.get('/:id/audit-logs', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.getBillAuditLogs);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), billsController.deleteBill);

// Any authenticated user can pay their own bill (service enforces ownership)
router.post('/:id/pay', billsController.recordPayment);
router.get('/:id', billsController.getBillById);

module.exports = router;
