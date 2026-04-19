const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const c = require('./auth.controller');

// Public routes
router.post('/check-societies', c.checkSocieties);
router.post('/login',           c.login);
router.post('/refresh',         c.refresh);
router.post('/logout',          c.logout);
router.post('/forgot-password', c.forgotPassword);
router.post('/verify-otp',      c.verifyOtp);

// Protected routes
router.get('/me',               auth, c.me);
router.post('/change-password', auth, c.changePassword);

module.exports = router;
