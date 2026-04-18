const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const createUploader = require('../../middleware/uploadGeneric');
const c = require('./complaints.controller');

const upload = createUploader('complaints');

router.use(auth);

router.get('/', c.getComplaints);
router.get('/:id', c.getComplaintById);
router.post('/', upload.array('attachments', 5), c.createComplaint);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.updateComplaint);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteComplaint);

module.exports = router;
