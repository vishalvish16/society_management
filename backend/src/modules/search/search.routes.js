const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const c = require('./search.controller');

router.use(auth);

// GET /api/search?q=...
router.get('/', c.search);

module.exports = router;

