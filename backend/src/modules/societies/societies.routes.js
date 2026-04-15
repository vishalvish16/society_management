const { Router } = require('express');
const societiesController = require('./societies.controller');
const authMiddleware = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();

// All society management routes require SUPER_ADMIN
router.use(authMiddleware);
router.use(roleGuard('SUPER_ADMIN'));

router.get('/', societiesController.listSocieties);
router.post('/', societiesController.createSociety);
// Specific sub-routes BEFORE generic /:id to avoid route collision
router.patch('/:id/toggle-status', societiesController.toggleSocietyStatus);
router.post('/:id/reset-password', societiesController.resetChairmanPassword);
router.post('/:id/chairman', societiesController.upsertChairman);
router.get('/:id/settings', societiesController.getSocietySettings);
router.patch('/:id/settings', societiesController.updateSocietySettings);
router.get('/:id', societiesController.getSociety);
router.patch('/:id', societiesController.updateSociety);
router.delete('/:id', societiesController.deactivateSociety);

module.exports = router;
