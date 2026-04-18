const { Router } = require('express');
const paymentsController = require('./payments.controller');
const authMiddleware = require('../../middleware/auth');

const router = Router();
router.use(authMiddleware);

// Public config (key_id only — never secret)
router.get('/config', paymentsController.getPaymentConfig);

// Any authenticated user can create an order for their own bill
router.post('/create-order', paymentsController.createOrder);

// Verify and record after Razorpay SDK callback
router.post('/verify', paymentsController.verifyPayment);

// Donation orders and verifications
router.post('/create-donation-order', paymentsController.createDonationOrder);
router.post('/verify-donation', paymentsController.verifyDonationPayment);

// Complaint payments
router.post('/create-complaint-order', paymentsController.createComplaintOrder);
router.post('/verify-complaint', paymentsController.verifyComplaintPayment);

module.exports = router;
