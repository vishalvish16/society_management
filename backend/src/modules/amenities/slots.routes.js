const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const c = require('./slots.controller');

router.use(auth);

router.get('/', c.getAvailableSlots);

module.exports = router;
