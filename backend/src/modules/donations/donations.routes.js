const { Router } = require('express');
const ctrl = require('./donations.controller');
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');

const router = Router();
router.use(auth);

const checkPlanLimit = require('../../middleware/checkPlanLimit');

const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY', 'TREASURER', 'ASSISTANT_TREASURER'];
const ALL_ROLES = [...ADMIN_ROLES, 'MEMBER', 'RESIDENT'];

router.get('/balance', roleGuard(ADMIN_ROLES), checkPlanLimit('donations'), ctrl.getSocietyBalance);

router.get('/campaigns', roleGuard(ALL_ROLES), checkPlanLimit('donations'), ctrl.listCampaigns);
router.post('/campaigns', roleGuard(ADMIN_ROLES), checkPlanLimit('donations'), ctrl.createCampaign);
router.patch('/campaigns/:id', roleGuard(ADMIN_ROLES), checkPlanLimit('donations'), ctrl.updateCampaign);

router.get('/', roleGuard(ALL_ROLES), checkPlanLimit('donations'), ctrl.listDonations);
router.post('/', roleGuard(ALL_ROLES), checkPlanLimit('donations'), ctrl.makeDonation);

module.exports = router;
