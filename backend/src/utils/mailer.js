/**
 * mailer.js — Nodemailer-based email utility.
 *
 * Usage:
 *   const { sendMail, sendVisitorQrMail } = require('./mailer');
 *
 * All functions are fire-and-forget safe — they log errors but never throw.
 * The transporter is lazily created on first use so the server starts even
 * if SMTP credentials are missing.
 */

const nodemailer = require('nodemailer');

// ─── Transporter (singleton) ──────────────────────────────────────────────────

let _transporter = null;

function getTransporter() {
  if (_transporter) return _transporter;

  const { SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS } = process.env;

  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) {
    console.warn('[Mailer] SMTP credentials not configured — emails will not be sent.');
    return null;
  }

  _transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: parseInt(SMTP_PORT || '465', 10),
    secure: SMTP_SECURE === 'true',          // true → TLS (port 465), false → STARTTLS
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });

  return _transporter;
}

// ─── Generic send helper ──────────────────────────────────────────────────────

/**
 * Send an email.
 *
 * @param {Object} opts
 * @param {string|string[]} opts.to         Recipient(s)
 * @param {string}          opts.subject    Subject line
 * @param {string}          [opts.text]     Plain-text body
 * @param {string}          [opts.html]     HTML body (preferred over text)
 * @param {Array}           [opts.attachments] Nodemailer attachments array
 * @returns {Promise<boolean>}  true if sent, false if skipped/failed
 */
async function sendMail({ to, subject, text, html, attachments = [] }) {
  const transporter = getTransporter();
  if (!transporter) return false;

  const fromName  = process.env.SMTP_FROM_NAME  || 'Society Management';
  const fromEmail = process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER;

  try {
    const info = await transporter.sendMail({
      from: `"${fromName}" <${fromEmail}>`,
      to: Array.isArray(to) ? to.join(', ') : to,
      subject,
      text,
      html,
      attachments,
    });
    console.log(`[Mailer] Sent "${subject}" → ${to} (${info.messageId})`);
    return true;
  } catch (err) {
    console.error('[Mailer] Send error:', err.message);
    return false;
  }
}

// ─── Visitor QR mailer ────────────────────────────────────────────────────────

/**
 * Send the visitor QR-code pass email.
 *
 * @param {Object} opts
 * @param {string} opts.to               Visitor's email address
 * @param {string} opts.visitorName      Visitor display name
 * @param {string} opts.societyName      Society name
 * @param {string} opts.unitCode         Unit the visitor is coming to (e.g. A-101)
 * @param {string} opts.hostName         Name of the resident who invited
 * @param {string} opts.expectedArrival  Human-readable expected arrival (or null)
 * @param {string} opts.qrExpiresAt      Human-readable expiry string
 * @param {Buffer} opts.qrImageBuffer    PNG buffer of the QR code
 * @param {string} opts.qrToken          Raw token (shown as fallback text)
 */
async function sendVisitorQrMail({
  to,
  visitorName,
  societyName,
  unitCode,
  hostName,
  expectedArrival,
  qrExpiresAt,
  qrImageBuffer,
  qrToken,
}) {
  const subject = `Your Visitor Pass — ${societyName}`;

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Visitor Pass</title>
  <style>
    body { margin:0; padding:0; background:#F5F7FA; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
    .wrapper { max-width:520px; margin:32px auto; background:#fff; border-radius:14px; overflow:hidden;
               box-shadow:0 4px 24px rgba(0,0,0,0.08); }
    .header  { background:#1B3A6B; padding:28px 32px; text-align:center; }
    .header h1 { margin:0; color:#fff; font-size:22px; font-weight:700; letter-spacing:-0.3px; }
    .header p  { margin:6px 0 0; color:rgba(255,255,255,0.75); font-size:13px; }
    .body    { padding:28px 32px; }
    .greeting { font-size:16px; color:#1A1A2E; font-weight:600; margin-bottom:6px; }
    .info-row { display:flex; justify-content:space-between; border-bottom:1px solid #E8EAF6;
                padding:10px 0; font-size:14px; }
    .info-row .label { color:#8B8FA8; }
    .info-row .value { color:#1A1A2E; font-weight:600; }
    .qr-section { text-align:center; margin:24px 0; }
    .qr-section img { width:200px; height:200px; border:6px solid #EEF2FF; border-radius:12px; }
    .qr-note { font-size:12px; color:#8B8FA8; margin-top:8px; }
    .token-box { background:#F5F7FA; border-radius:8px; padding:10px 16px; text-align:center;
                 font-family:monospace; font-size:13px; color:#1B3A6B; letter-spacing:0.5px;
                 word-break:break-all; margin-top:12px; }
    .footer  { background:#F5F7FA; padding:20px 32px; text-align:center; font-size:12px; color:#8B8FA8; }
    .footer a { color:#1B3A6B; text-decoration:none; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>🏢 ${societyName}</h1>
      <p>Visitor Entry Pass</p>
    </div>
    <div class="body">
      <p class="greeting">Hello, ${visitorName}!</p>
      <p style="font-size:14px;color:#4A4A6A;margin-top:0">
        You have been invited to visit <strong>${societyName}</strong>.
        Please show the QR code below to the security guard at the gate.
      </p>

      <div class="info-row"><span class="label">Visiting</span><span class="value">Unit ${unitCode}</span></div>
      <div class="info-row"><span class="label">Invited by</span><span class="value">${hostName}</span></div>
      ${expectedArrival ? `<div class="info-row"><span class="label">Expected arrival</span><span class="value">${expectedArrival}</span></div>` : ''}
      <div class="info-row"><span class="label">Valid until</span><span class="value">${qrExpiresAt}</span></div>

      <div class="qr-section">
        <img src="cid:visitor_qr" alt="Visitor QR Code" />
        <p class="qr-note">Show this QR code at the gate</p>
        <div class="token-box">${qrToken}</div>
      </div>

      <p style="font-size:12px;color:#8B8FA8;margin-top:4px;text-align:center">
        This pass is single-use and expires on <strong>${qrExpiresAt}</strong>.
        Do not share it with others.
      </p>
    </div>
    <div class="footer">
      Powered by <a href="#">Society Management System</a> &nbsp;|&nbsp;
      This is an automated email — please do not reply.
    </div>
  </div>
</body>
</html>`;

  const text = `
Hello ${visitorName},

You have been invited to visit ${societyName}.

Unit: ${unitCode}
Invited by: ${hostName}
${expectedArrival ? `Expected arrival: ${expectedArrival}\n` : ''}Valid until: ${qrExpiresAt}

Your QR token: ${qrToken}

Please show this email (or the attached QR code) to the security guard at the gate.

-- Society Management System
`;

  return sendMail({
    to,
    subject,
    text,
    html,
    attachments: [
      {
        filename: 'visitor-pass-qr.png',
        content: qrImageBuffer,
        contentType: 'image/png',
        cid: 'visitor_qr',   // referenced in <img src="cid:visitor_qr">
      },
    ],
  });
}

module.exports = { sendMail, sendVisitorQrMail };
