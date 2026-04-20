const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const createUploader = require('../../middleware/uploadGeneric');
const c = require('./domestichelp.controller');

const upload = createUploader('domestichelp');

router.use(auth);

router.get('/logs/today', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('domestic_help'), c.getTodayLogs);
router.get('/code/:code', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), checkPlanLimit('domestic_help'), c.getByCode);
router.get('/unit/:id', checkPlanLimit('domestic_help'), c.getByUnit);
router.get('/', checkPlanLimit('domestic_help'), c.list);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('domestic_help'), upload.single('photo'), c.create);
router.post('/log', roleGuard(['WATCHMAN']), checkPlanLimit('domestic_help'), c.logEntry);
router.patch('/:id/suspend', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('domestic_help'), c.suspend);
router.patch('/:id/remove', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('domestic_help'), c.remove);
router.get('/:id/logs', checkPlanLimit('domestic_help'), c.getLogs);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), checkPlanLimit('domestic_help'), upload.single('photo'), c.update);

module.exports = router;

