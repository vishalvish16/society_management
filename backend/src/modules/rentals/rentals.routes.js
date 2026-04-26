const { Router } = require('express');
const controller = require('./rentals.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const { ADMIN_ROLES } = require('../../config/constants');
const createUploader = require('../../middleware/uploadGeneric');

const router = Router();
const upload = createUploader('rentals');

router.use(authMiddleware);

router.get('/', controller.listRentals);
router.get('/:id', controller.getRental);
router.post('/', roleGuard(ADMIN_ROLES), upload.array('documents', 10), controller.createRental);
router.patch('/:id', roleGuard(ADMIN_ROLES), upload.array('documents', 10), controller.updateRental);
router.patch('/:id/end', roleGuard(ADMIN_ROLES), controller.endRental);
router.delete('/:id', roleGuard(ADMIN_ROLES), controller.deleteRental);
router.put('/:id/members', roleGuard(ADMIN_ROLES), controller.syncMembers);
router.delete('/:id/documents/:docId', roleGuard(ADMIN_ROLES), controller.deleteDocument);

module.exports = router;
