const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const createUploader = require('../../middleware/uploadGeneric');
const c = require('./domestichelp.controller');

const upload = createUploader('domestichelp');

router.use(auth);

router.get('/logs/today', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getTodayLogs);
router.get('/code/:code', roleGuard(['WATCHMAN', 'PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getByCode);
router.get('/unit/:id', c.getByUnit);
router.get('/', c.list);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), upload.single('photo'), c.create);
router.post('/log', roleGuard(['WATCHMAN']), c.logEntry);
router.patch('/:id/suspend', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.suspend);
router.patch('/:id/remove', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), c.remove);
router.get('/:id/logs', c.getLogs);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'RESIDENT', 'MEMBER']), upload.single('photo'), c.update);

module.exports = router;

