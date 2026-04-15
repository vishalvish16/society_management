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

module.exports = router;
