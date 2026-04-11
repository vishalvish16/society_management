const { Router } = require('express');
const societiesController = require('./societies.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// All society management routes require SUPER_ADMIN
router.use(authMiddleware);
router.use(roleGuard('SUPER_ADMIN'));

router.get('/', societiesController.listSocieties);
router.get('/:id', societiesController.getSociety);
router.post('/', societiesController.createSociety);
router.patch('/:id', societiesController.updateSociety);
router.delete('/:id', societiesController.deactivateSociety);

module.exports = router;

router.patch('/:id/toggle-status', societiesController.toggleSocietyStatus);
router.post('/:id/reset-password', societiesController.resetSocietyPassword);
