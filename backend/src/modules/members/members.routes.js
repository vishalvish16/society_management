const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const { ADMIN_ROLES } = require('../../config/constants');
const c = require('./members.controller');

router.use(auth);

router.get('/', c.getMembers);
router.post('/', roleGuard([...ADMIN_ROLES, 'MEMBER', 'RESIDENT']), c.createMember);
router.patch('/:id', roleGuard(ADMIN_ROLES), c.updateMember);
router.delete('/:id', roleGuard(ADMIN_ROLES), c.deleteMember);
router.post('/:id/reset-password', roleGuard(ADMIN_ROLES), c.resetPassword);

module.exports = router;
