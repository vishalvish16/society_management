const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./notices.controller');

router.use(auth);

router.get('/', c.getNotices);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createNotice);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateNotice);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteNotice);

module.exports = router;
