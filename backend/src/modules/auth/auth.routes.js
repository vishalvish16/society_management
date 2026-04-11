const express = require('express');
const router = express.Router();
const authController = require('./auth.controller');
const auth = require('../../middleware/auth');

router.post('/login',    authController.login);
router.post('/register', authController.register);
router.post('/logout',   authController.logout);
router.get('/me',        auth, authController.me);

module.exports = router;
