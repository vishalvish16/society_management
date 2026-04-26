const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const createUploader = require('../../middleware/uploadGeneric');
const c = require('./events.controller');

const upload = createUploader('events');

router.use(auth);

// List & detail (any authenticated society member)
router.get('/', c.listEvents);
router.get('/:id', c.getEventById);

// Admin actions
router.post('/', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), upload.array('attachments', 5), c.createEvent);
router.patch('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), upload.array('attachments', 5), c.updateEvent);
router.delete('/:id', roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY']), c.deleteEvent);

// Registration (any member)
router.post('/:id/register', c.registerForEvent);
router.delete('/:id/register', c.cancelRegistration);

// View registrations (admin / creator)
router.get('/:id/registrations', c.getRegistrations);

module.exports = router;
