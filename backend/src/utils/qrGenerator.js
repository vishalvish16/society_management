/**
 * qrGenerator.js — QR code generation utilities.
 *
 * Uses the `qrcode` npm package to produce:
 *  • PNG Buffer (for email attachment / inline CID)
 *  • Data-URI string (for embedding in HTML)
 *  • SVG string (for scalable rendering)
 *
 * Usage:
 *   const { generateQrBuffer, generateQrDataUri, generateQrSvg } = require('./qrGenerator');
 *
 *   const buf = await generateQrBuffer('my-token-uuid');
 *   const uri = await generateQrDataUri('my-token-uuid');
 */

const QRCode = require('qrcode');

/** Default visual options shared by all generators */
const DEFAULT_OPTIONS = {
  errorCorrectionLevel: 'H',   // High — survives logos or minor damage
  margin: 2,
  color: {
    dark:  '#1B3A6B',   // Society primary brand colour
    light: '#FFFFFF',
  },
};

// ─── PNG Buffer ───────────────────────────────────────────────────────────────

/**
 * Generate a QR code as a PNG Buffer.
 * Ideal for email attachments and inline CID images.
 *
 * @param {string} data    The string to encode (token, URL, etc.)
 * @param {number} [size]  Pixel size of the image (default 400)
 * @returns {Promise<Buffer>}
 */
async function generateQrBuffer(data, size = 400) {
  return QRCode.toBuffer(data, {
    ...DEFAULT_OPTIONS,
    width: size,
    type:  'png',
  });
}

// ─── Data URI ─────────────────────────────────────────────────────────────────

/**
 * Generate a QR code as a base-64 data URI (data:image/png;base64,…).
 * Ideal for embedding directly in HTML <img> tags.
 *
 * @param {string} data
 * @param {number} [size]
 * @returns {Promise<string>}
 */
async function generateQrDataUri(data, size = 300) {
  return QRCode.toDataURL(data, {
    ...DEFAULT_OPTIONS,
    width: size,
  });
}

// ─── SVG string ───────────────────────────────────────────────────────────────

/**
 * Generate a QR code as an SVG string.
 * Ideal for scalable rendering in web pages.
 *
 * @param {string} data
 * @returns {Promise<string>}
 */
async function generateQrSvg(data) {
  return QRCode.toString(data, {
    ...DEFAULT_OPTIONS,
    type: 'svg',
  });
}

// ─── Visitor QR payload builder ───────────────────────────────────────────────

/**
 * Build the canonical string that gets encoded into the visitor QR.
 *
 * The app's scanner reads this string when decoding the QR.
 * Format kept intentionally simple so the watchman app just extracts the token.
 *
 * @param {string} qrToken   UUID token stored in DB
 * @param {string} [baseUrl] Optional deep-link base (e.g. https://app.example.com/validate/)
 * @returns {string}
 */
function buildVisitorQrPayload(qrToken, baseUrl) {
  if (baseUrl) {
    const base = baseUrl.replace(/\/?$/, '/');
    return `${base}${qrToken}`;
  }
  return qrToken;   // Plain token — watchman app posts it to /api/visitors/validate
}

module.exports = {
  generateQrBuffer,
  generateQrDataUri,
  generateQrSvg,
  buildVisitorQrPayload,
};
