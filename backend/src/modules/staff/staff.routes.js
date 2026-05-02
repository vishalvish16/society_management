const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./staff.controller');

router.use(auth);

router.get('/', c.listStaff);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createStaff);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateStaff);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteStaff);
router.post('/:id/attendance', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), c.markAttendance);
router.get('/:id/attendance', c.getAttendance);
router.get('/attendance-summary', c.getAttendanceSummary);
router.get('/attendance-sheet', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), c.getAttendanceSheet);
router.post('/attendance-bulk', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'WATCHMAN']), c.markAttendanceBulk);
router.get('/salary-payments', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), c.listSalaryPayments);
router.get('/salary-payments/history', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), c.getSalaryPaymentHistory);
router.post('/salary-payments', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), c.markSalaryPaid);
router.post('/salary-payments/bulk', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), c.markSalaryPaidBulk);
router.post('/salary-payments/:id/cancel', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), c.cancelSalaryPayment);
router.post('/salary-payments/cancel-bulk', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER']), c.cancelSalaryPaymentsBulk);
router.post('/:id/reset-password', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.resetWatchmanPassword);

module.exports = router;
