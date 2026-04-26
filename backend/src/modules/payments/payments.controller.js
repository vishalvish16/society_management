const Razorpay = require('razorpay');
const crypto = require('crypto');
const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');

/**
 * Get the Razorpay instance configured with the society's keys.
 * Returns null if not configured.
 */
async function getRazorpayForSociety(societyId) {
  const society = await prisma.society.findUnique({
    where: { id: societyId },
    select: { settings: true },
  });
  const settings = society?.settings || {};
  const keyId = settings.razorpayKeyId;
  const keySecret = settings.razorpayKeySecret;
  if (!keyId || !keySecret) return null;
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

/**
 * GET /api/payments/config
 * Returns the public key_id and active gateway for the client.
 * Safe to expose — key_secret is never sent.
 */
async function getPaymentConfig(req, res) {
  try {
    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    const settings = society?.settings || {};
    return sendSuccess(res, {
      activeGateway: settings.activeGateway || null,
      razorpayKeyId: settings.razorpayKeyId || null,
      // never send razorpayKeySecret
    }, 'Payment config retrieved');
  } catch (err) {
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/create-order
 * Creates a Razorpay order for a bill.
 * Body: { billId }
 */
async function createOrder(req, res) {
  try {
    const { billId } = req.body;
    if (!billId) return sendError(res, 'billId is required', 400);

    const bill = await prisma.maintenanceBill.findUnique({
      where: { id: billId },
      include: { unit: { select: { fullCode: true } } },
    });

    if (!bill) return sendError(res, 'Bill not found', 404);
    if (bill.societyId !== req.user.societyId)
      return sendError(res, 'Access denied', 403);
    if (bill.status === 'PAID') return sendError(res, 'Bill is already paid', 400);

    const remaining = Number(bill.totalDue) - Number(bill.paidAmount);
    if (remaining <= 0) return sendError(res, 'No outstanding amount', 400);

    const razorpay = await getRazorpayForSociety(req.user.societyId);
    if (!razorpay)
      return sendError(res, 'Payment gateway not configured. Contact your admin.', 400);

    const order = await razorpay.orders.create({
      amount: Math.round(remaining * 100), // paise
      currency: 'INR',
      receipt: `bill_${billId.slice(0, 20)}`,
      notes: {
        billId,
        unitCode: bill.unit?.fullCode ?? '',
        societyId: req.user.societyId,
      },
    });

    return sendSuccess(res, {
      orderId: order.id,
      amount: order.amount,        // in paise
      currency: order.currency,
      billId,
      remaining,
    }, 'Order created');
  } catch (err) {
    console.error('Create order error:', err.message);
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/verify
 * Verifies Razorpay signature and records the payment.
 * Body: { billId, razorpayOrderId, razorpayPaymentId, razorpaySignature, paidAmount }
 */
async function verifyPayment(req, res) {
  try {
    const { billId, razorpayOrderId, razorpayPaymentId, razorpaySignature, paidAmount } = req.body;

    if (!billId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return sendError(res, 'Missing payment verification fields', 400);
    }

    // Fetch the society's key secret for signature verification
    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    const keySecret = society?.settings?.razorpayKeySecret;
    if (!keySecret) return sendError(res, 'Payment gateway not configured', 400);

    // Verify HMAC signature
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      return sendError(res, 'Payment verification failed — invalid signature', 400);
    }

    // Signature valid — record the payment
    const bill = await prisma.maintenanceBill.findUnique({ where: { id: billId } });
    if (!bill) return sendError(res, 'Bill not found', 404);
    if (bill.societyId !== req.user.societyId) return sendError(res, 'Access denied', 403);

    const amount = paidAmount ? Number(paidAmount) : (Number(bill.totalDue) - Number(bill.paidAmount));
    const newPaidAmount = Number(bill.paidAmount) + amount;
    const remaining = Number(bill.totalDue) - newPaidAmount;
    const newStatus = remaining <= 0 ? 'PAID' : 'PARTIAL';

    const updated = await prisma.maintenanceBill.update({
      where: { id: billId },
      data: {
        paidAmount: newPaidAmount,
        paidAt: new Date(),
        paymentMethod: 'ONLINE',
        notes: `Razorpay | Order: ${razorpayOrderId} | Payment: ${razorpayPaymentId}`,
        status: newStatus,
      },
    });

    return sendSuccess(res, {
      bill: updated,
      razorpayPaymentId,
      razorpayOrderId,
    }, 'Payment verified and recorded');
  } catch (err) {
    console.error('Verify payment error:', err.message);
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/create-donation-order
 */
async function createDonationOrder(req, res) {
  try {
    const { amount, campaignId } = req.body;
    if (!amount || amount <= 0) return sendError(res, 'amount is required and must be > 0', 400);

    const razorpay = await getRazorpayForSociety(req.user.societyId);
    if (!razorpay)
      return sendError(res, 'Payment gateway not configured. Contact your admin.', 400);

    const order = await razorpay.orders.create({
      amount: Math.round(amount * 100), // paise
      currency: 'INR',
      receipt: `don_${Date.now()}`,
      notes: {
        campaignId: campaignId || '',
        societyId: req.user.societyId,
        isDonation: 'true'
      },
    });

    return sendSuccess(res, {
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
    }, 'Donation order created');
  } catch (err) {
    console.error('Create donation order error:', err.message);
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/verify-donation
 */
async function verifyDonationPayment(req, res) {
  try {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature, amount, campaignId, note } = req.body;

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature || !amount) {
      return sendError(res, 'Missing payment verification fields', 400);
    }

    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    const keySecret = society?.settings?.razorpayKeySecret;
    if (!keySecret) return sendError(res, 'Payment gateway not configured', 400);

    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      return sendError(res, 'Payment verification failed — invalid signature', 400);
    }

    const donation = await prisma.donation.create({
      data: {
        societyId: req.user.societyId,
        donorId: req.user.id,
        campaignId: campaignId || null,
        amount: Number(amount),
        paymentMethod: 'ONLINE',
        note: `Razorpay | Order: ${razorpayOrderId} | Payment: ${razorpayPaymentId}${note ? ' | User Note: ' + note : ''}`,
        paidAt: new Date(),
      }
    });

    return sendSuccess(res, {
      donation,
      razorpayPaymentId,
      razorpayOrderId,
    }, 'Donation verified and recorded');
  } catch (err) {
    console.error('Verify donation payment error:', err.message);
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/create-complaint-order
 */
async function createComplaintOrder(req, res) {
  try {
    const { complaintId } = req.body;
    if (!complaintId) return sendError(res, 'complaintId is required', 400);

    const complaint = await prisma.complaint.findUnique({
      where: { id: complaintId },
      include: { unit: { select: { fullCode: true } } },
    });

    if (!complaint) return sendError(res, 'Complaint not found', 404);
    if (complaint.societyId !== req.user.societyId)
      return sendError(res, 'Access denied', 403);
    if (complaint.paymentStatus === 'PAID')
      return sendError(res, 'Complaint is already paid', 400);

    const amount = Number(complaint.amount) || 0;
    const paid = Number(complaint.paidAmount) || 0;
    const remaining = amount - paid;
    if (remaining <= 0) return sendError(res, 'No outstanding amount', 400);

    const razorpay = await getRazorpayForSociety(req.user.societyId);
    if (!razorpay)
      return sendError(res, 'Payment gateway not configured. Contact your admin.', 400);

    const order = await razorpay.orders.create({
      amount: Math.round(remaining * 100), // paise
      currency: 'INR',
      receipt: `comp_${complaintId.slice(0, 20)}`,
      notes: {
        complaintId,
        unitCode: complaint.unit?.fullCode ?? '',
        societyId: req.user.societyId,
      },
    });

    return sendSuccess(res, {
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      complaintId,
      remaining,
    }, 'Complaint order created');
  } catch (err) {
    console.error('Create complaint order error:', err.message);
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/verify-complaint
 */
async function verifyComplaintPayment(req, res) {
  try {
    const { complaintId, razorpayOrderId, razorpayPaymentId, razorpaySignature, paidAmount } = req.body;

    if (!complaintId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return sendError(res, 'Missing payment verification fields', 400);
    }

    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    const keySecret = society?.settings?.razorpayKeySecret;
    if (!keySecret) return sendError(res, 'Payment gateway not configured', 400);

    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      return sendError(res, 'Payment verification failed — invalid signature', 400);
    }

    const complaint = await prisma.complaint.findUnique({ where: { id: complaintId } });
    if (!complaint) return sendError(res, 'Complaint not found', 404);

    const amount = paidAmount ? Number(paidAmount) : (Number(complaint.amount) - Number(complaint.paidAmount));
    const newPaidAmount = Number(complaint.paidAmount) + amount;
    const remaining = Number(complaint.amount) - newPaidAmount;
    const newStatus = remaining <= 0 ? 'PAID' : 'PARTIAL';

    const updated = await prisma.complaint.update({
      where: { id: complaintId },
      data: {
        paidAmount: newPaidAmount,
        paidAt: new Date(),
        paymentMethod: 'ONLINE',
        transactionId: razorpayPaymentId,
        paymentStatus: newStatus,
      },
    });

    return sendSuccess(res, {
      complaint: updated,
      razorpayPaymentId,
      razorpayOrderId,
    }, 'Complaint payment verified and recorded');
  } catch (err) {
    console.error('Verify complaint payment error:', err.message);
    return sendError(res, err.message, 500);
  }
}

module.exports = { 
  getPaymentConfig, 
  createOrder, 
  verifyPayment, 
  createDonationOrder, 
  verifyDonationPayment,
  createComplaintOrder,
  verifyComplaintPayment,
  createSuggestionOrder,
  verifySuggestionPayment
};

/**
 * POST /api/payments/create-suggestion-order
 */
async function createSuggestionOrder(req, res) {
  try {
    const { suggestionId } = req.body;
    if (!suggestionId) return sendError(res, 'suggestionId is required', 400);

    const suggestion = await prisma.suggestion.findUnique({
      where: { id: suggestionId },
      include: { unit: { select: { fullCode: true } } },
    });

    if (!suggestion) return sendError(res, 'Suggestion not found', 404);
    if (suggestion.societyId !== req.user.societyId) return sendError(res, 'Access denied', 403);
    if (suggestion.paymentStatus === 'PAID') return sendError(res, 'Suggestion is already paid', 400);

    const amount = Number(suggestion.amount) || 0;
    const paid = Number(suggestion.paidAmount) || 0;
    const remaining = amount - paid;
    if (remaining <= 0) return sendError(res, 'No outstanding amount', 400);

    const razorpay = await getRazorpayForSociety(req.user.societyId);
    if (!razorpay) return sendError(res, 'Payment gateway not configured. Contact your admin.', 400);

    const order = await razorpay.orders.create({
      amount: Math.round(remaining * 100),
      currency: 'INR',
      receipt: `sug_${suggestionId.slice(0, 20)}`,
      notes: {
        suggestionId,
        unitCode: suggestion.unit?.fullCode ?? '',
        societyId: req.user.societyId,
      },
    });

    return sendSuccess(
      res,
      {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        suggestionId,
        remaining,
      },
      'Suggestion order created'
    );
  } catch (err) {
    console.error('Create suggestion order error:', err.message);
    return sendError(res, err.message, 500);
  }
}

/**
 * POST /api/payments/verify-suggestion
 */
async function verifySuggestionPayment(req, res) {
  try {
    const { suggestionId, razorpayOrderId, razorpayPaymentId, razorpaySignature, paidAmount } = req.body;

    if (!suggestionId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return sendError(res, 'Missing payment verification fields', 400);
    }

    const society = await prisma.society.findUnique({
      where: { id: req.user.societyId },
      select: { settings: true },
    });
    const keySecret = society?.settings?.razorpayKeySecret;
    if (!keySecret) return sendError(res, 'Payment gateway not configured', 400);

    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      return sendError(res, 'Payment verification failed — invalid signature', 400);
    }

    const suggestion = await prisma.suggestion.findUnique({ where: { id: suggestionId } });
    if (!suggestion) return sendError(res, 'Suggestion not found', 404);

    const amount = paidAmount
      ? Number(paidAmount)
      : Number(suggestion.amount) - Number(suggestion.paidAmount);
    const newPaidAmount = Number(suggestion.paidAmount) + amount;
    const remaining = Number(suggestion.amount) - newPaidAmount;
    const newStatus = remaining <= 0 ? 'PAID' : 'PARTIAL';

    const updated = await prisma.suggestion.update({
      where: { id: suggestionId },
      data: {
        paidAmount: newPaidAmount,
        paidAt: new Date(),
        paymentMethod: 'ONLINE',
        transactionId: razorpayPaymentId,
        paymentStatus: newStatus,
      },
    });

    return sendSuccess(
      res,
      {
        suggestion: updated,
        razorpayPaymentId,
        razorpayOrderId,
      },
      'Suggestion payment verified and recorded'
    );
  } catch (err) {
    console.error('Verify suggestion payment error:', err.message);
    return sendError(res, err.message, 500);
  }
}
