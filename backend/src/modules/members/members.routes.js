const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth-middleware');
const c = require('./members.controller');

router.get('/',    auth, c.getMembers);
router.put('/:id', auth, c.updateMember);
router.delete('/:id', auth, c.deleteMember);

module.exports = router;
