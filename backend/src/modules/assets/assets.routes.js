const { Router } = require('express');
const ctrl = require('./assets.controller');
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const upload = require('../../middleware/uploadAsset');

const router = Router();

const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'VICE_CHAIRMAN', 'TREASURER'];
const READ_ROLES = [...ADMIN_ROLES, 'ASSISTANT_SECRETARY', 'ASSISTANT_TREASURER', 'MEMBER', 'RESIDENT'];

router.use(auth);
router.use(checkPlanLimit('asset_management'));

router.get('/categories', roleGuard(READ_ROLES), ctrl.getCategories);
router.get('/summary', roleGuard(ADMIN_ROLES), ctrl.getSummary);
router.get('/', roleGuard(READ_ROLES), ctrl.listAssets);
router.get('/:id', roleGuard(READ_ROLES), ctrl.getAsset);

router.post('/', roleGuard(ADMIN_ROLES), upload.array('attachments', 5), ctrl.createAsset);
router.put('/:id', roleGuard(ADMIN_ROLES), upload.array('attachments', 5), ctrl.updateAsset);
router.delete('/:id', roleGuard(ADMIN_ROLES), ctrl.deleteAsset);

router.delete('/:id/attachments/:attachmentId', roleGuard(ADMIN_ROLES), ctrl.deleteAttachment);
router.post('/:id/maintenance', roleGuard(ADMIN_ROLES), ctrl.addMaintenanceLog);

module.exports = router;
