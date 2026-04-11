const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const c = require('./amenities.controller');

router.get('/',    auth, c.getAllAmenities);
router.post('/',   auth, c.createAmenity);
router.delete('/:id', auth, c.deleteAmenityById);

module.exports = router;
