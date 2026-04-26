const express = require('express');
const router = express.Router();

const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const c = require('./polls.controller');

router.use(auth);

// Creator / admin actions
router.get('/created', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.listMyCreatedPolls);
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.createPoll);
router.post('/:id/close', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.closePoll);
router.get('/:id/results', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.getPollResults);

// Recipient actions
router.get('/inbox', c.listInboxPolls);
router.get('/:id', c.getPollById);
router.post('/:id/vote', c.voteOnPoll);

module.exports = router;

