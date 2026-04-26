const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const createUploader = require('../../middleware/uploadGeneric');
const c = require('./suggestions.controller');

const upload = createUploader('suggestions');

router.use(auth);

router.get('/', c.getSuggestions);
router.get('/:id', c.getSuggestionById);
router.post('/', upload.array('attachments', 5), c.createSuggestion);
router.patch(
  '/:id',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']),
  checkPlanLimit('complaint_assignment'),
  c.updateSuggestion
);
router.delete(
  '/:id',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']),
  c.deleteSuggestion
);

module.exports = router;

