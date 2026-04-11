const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth-middleware');
const c = require('./notices.controller');

router.get('/',    auth, c.getNotices);
router.post('/',   auth, c.createNotice);
router.put('/:id', auth, c.updateNotice);
router.delete('/:id', auth, c.deleteNotice);

module.exports = router;
