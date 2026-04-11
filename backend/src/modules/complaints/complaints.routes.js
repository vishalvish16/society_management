const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth-middleware');
const c = require('./complaints.controller');

router.get('/',    auth, c.getComplaints);
router.post('/',   auth, c.createComplaint);
router.put('/:id', auth, c.updateComplaint);
router.delete('/:id', auth, c.deleteComplaint);

module.exports = router;
