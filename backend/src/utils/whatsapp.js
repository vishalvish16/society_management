/**
 * whatsapp.js — WhatsApp Business API service class.
 *
 * Supports the Interakt WABA API (https://www.interakt.ai) by default.
 * Easily swappable for any other Meta WABA-compatible provider by
 * changing WHATSAPP_API_URL + the request body shape in _send().
 *
 * Usage:
 *   const WhatsApp = require('./whatsapp');
 *
 *   // Plain text
 *   await WhatsApp.sendText('919876543210', 'Hello from Society!');
 *
 *   // Image with caption
 *   await WhatsApp.sendImage('919876543210', 'https://…/qr.png', 'Your visitor QR');
 *
 *   // Document (PDF)
 *   await WhatsApp.sendDocument('919876543210', 'https://…/pass.pdf', 'visitor-pass.pdf', 'Your entry pass');
 *
 *   // Interactive button message
 *   await WhatsApp.sendButtons('919876543210', 'Confirm your visit?', [
 *     { id: 'confirm', title: 'Yes, confirm' },
 *     { id: 'cancel',  title: 'Cancel' },
 *   ]);
 *
 *   // CTA link button message
 *   await WhatsApp.sendCtaLink('919876543210',
 *     'View your visitor pass',
 *     'Open Pass',
 *     'https://yourapp.com/pass/abc123'
 *   );
 *
 *   // Template message (approved WABA template)
 *   await WhatsApp.sendTemplate('919876543210', 'visitor_qr_pass', 'en', [
 *     { type: 'text', text: 'Rahul' },
 *     { type: 'text', text: 'A-101' },
 *   ]);
 *
 *   // Template with image header
 *   await WhatsApp.sendTemplateWithMedia('919876543210', 'visitor_qr_image', 'en',
 *     { type: 'image', url: 'https://…/qr.png' },
 *     [{ type: 'text', text: 'Rahul' }]
 *   );
 */

const https = require('https');
const http  = require('http');
const { URL } = require('url');

// ─── Internal HTTP helper ─────────────────────────────────────────────────────

/**
 * Minimal HTTP POST that does NOT require axios.
 * Returns { ok, status, data } — never throws.
 */
function _httpPost(urlStr, headers, body) {
  return new Promise((resolve) => {
    let parsed;
    try { parsed = new URL(urlStr); } catch {
      return resolve({ ok: false, status: 0, data: null, error: 'Invalid URL' });
    }

    const isHttps = parsed.protocol === 'https:';
    const lib     = isHttps ? https : http;
    const payload = JSON.stringify(body);

    const options = {
      hostname: parsed.hostname,
      port:     parsed.port || (isHttps ? 443 : 80),
      path:     parsed.pathname + parsed.search,
      method:   'POST',
      headers:  { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload), ...headers },
    };

    const req = lib.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => { raw += chunk; });
      res.on('end', () => {
        let data = null;
        try { data = JSON.parse(raw); } catch { data = raw; }
        resolve({ ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, data });
      });
    });

    req.on('error', (err) => resolve({ ok: false, status: 0, data: null, error: err.message }));
    req.write(payload);
    req.end();
  });
}

// ─── WhatsApp service class ───────────────────────────────────────────────────

class WhatsAppService {
  constructor() {
    this._apiKey  = process.env.WHATSAPP_API_KEY || '';
    this._phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID || '';
    this._apiUrl  = (process.env.WHATSAPP_API_URL || 'https://api.interakt.ai/v1/public/message/').replace(/\/?$/, '/');
  }

  get _configured() {
    return Boolean(this._apiKey && this._phoneId);
  }

  get _headers() {
    return {
      Authorization: `Basic ${this._apiKey}`,
    };
  }

  /**
   * Format phone: strip leading + or 0, ensure country code present.
   * Input: '9876543210', '+919876543210', '919876543210' → '919876543210'
   */
  _formatPhone(phone) {
    let p = String(phone).replace(/\D/g, '');
    // If 10 digits and starts with [6-9], assume Indian number
    if (p.length === 10 && /^[6-9]/.test(p)) p = '91' + p;
    return p;
  }

  /**
   * Core send — adapts message to Interakt's request shape.
   * @private
   */
  async _send(to, messageBody) {
    if (!this._configured) {
      console.warn('[WhatsApp] Not configured (WHATSAPP_API_KEY / WHATSAPP_PHONE_NUMBER_ID missing). Skipping send.');
      return false;
    }

    const phone = this._formatPhone(to);

    const payload = {
      countryCode: phone.slice(0, phone.length - 10),   // e.g. "91"
      phoneNumber: phone.slice(-10),                      // last 10 digits
      ...messageBody,
    };

    const result = await _httpPost(this._apiUrl, this._headers, payload);

    if (result.ok) {
      console.log(`[WhatsApp] Sent to ${phone} — type: ${messageBody.type || 'unknown'}`);
    } else {
      console.error(`[WhatsApp] Failed to ${phone} — ${result.status}:`, result.data || result.error);
    }

    return result.ok;
  }

  // ── Text ──────────────────────────────────────────────────────────────────

  /**
   * Send a plain-text message.
   * @param {string} to      Recipient phone (with or without country code)
   * @param {string} text    Message body (max 4096 chars)
   */
  async sendText(to, text) {
    return this._send(to, {
      type: 'Text',
      data: { message: text },
    });
  }

  // ── Media ─────────────────────────────────────────────────────────────────

  /**
   * Send an image.
   * @param {string} to
   * @param {string} imageUrl    Publicly accessible image URL
   * @param {string} [caption]   Optional caption text
   */
  async sendImage(to, imageUrl, caption = '') {
    return this._send(to, {
      type: 'Image',
      data: {
        mediaUrl: imageUrl,
        caption,
      },
    });
  }

  /**
   * Send a document / PDF.
   * @param {string} to
   * @param {string} docUrl      Publicly accessible document URL
   * @param {string} [filename]  File name shown in chat
   * @param {string} [caption]   Optional caption
   */
  async sendDocument(to, docUrl, filename = 'document', caption = '') {
    return this._send(to, {
      type: 'Document',
      data: {
        mediaUrl: docUrl,
        filename,
        caption,
      },
    });
  }

  /**
   * Send an audio file.
   * @param {string} to
   * @param {string} audioUrl   Publicly accessible audio URL (ogg/mp3)
   */
  async sendAudio(to, audioUrl) {
    return this._send(to, {
      type: 'Audio',
      data: { mediaUrl: audioUrl },
    });
  }

  /**
   * Send a video.
   * @param {string} to
   * @param {string} videoUrl   Publicly accessible video URL
   * @param {string} [caption]
   */
  async sendVideo(to, videoUrl, caption = '') {
    return this._send(to, {
      type: 'Video',
      data: { mediaUrl: videoUrl, caption },
    });
  }

  // ── Interactive: reply buttons ────────────────────────────────────────────

  /**
   * Send a message with up to 3 quick-reply buttons.
   * @param {string} to
   * @param {string} bodyText    Message body text
   * @param {Array<{id:string, title:string}>} buttons   Max 3
   * @param {string} [headerText]  Optional text header
   * @param {string} [footerText]  Optional footer
   */
  async sendButtons(to, bodyText, buttons, headerText = '', footerText = '') {
    if (!buttons?.length || buttons.length > 3) {
      throw new Error('sendButtons requires 1–3 buttons');
    }

    return this._send(to, {
      type: 'Button',
      data: {
        header: headerText ? { type: 'text', text: headerText } : undefined,
        body:   bodyText,
        footer: footerText || undefined,
        buttons: buttons.map((b) => ({
          type:  'reply',
          reply: { id: b.id, title: b.title },
        })),
      },
    });
  }

  // ── Interactive: list message ─────────────────────────────────────────────

  /**
   * Send a list picker message.
   * @param {string} to
   * @param {string} bodyText
   * @param {string} buttonLabel   Label on the list-open button
   * @param {Array<{ title:string, rows:Array<{id:string,title:string,description?:string}> }>} sections
   * @param {string} [headerText]
   * @param {string} [footerText]
   */
  async sendList(to, bodyText, buttonLabel, sections, headerText = '', footerText = '') {
    return this._send(to, {
      type: 'List',
      data: {
        header:  headerText ? { type: 'text', text: headerText } : undefined,
        body:    bodyText,
        footer:  footerText || undefined,
        action: {
          button:   buttonLabel,
          sections,
        },
      },
    });
  }

  // ── Interactive: CTA URL button ───────────────────────────────────────────

  /**
   * Send a single call-to-action link button message.
   * @param {string} to
   * @param {string} bodyText        Message body
   * @param {string} buttonLabel     Button text (max 20 chars)
   * @param {string} url             URL to open
   * @param {string} [headerText]
   * @param {string} [footerText]
   */
  async sendCtaLink(to, bodyText, buttonLabel, url, headerText = '', footerText = '') {
    return this._send(to, {
      type: 'Button',
      data: {
        header:  headerText ? { type: 'text', text: headerText } : undefined,
        body:    bodyText,
        footer:  footerText || undefined,
        buttons: [
          {
            type: 'url',
            url:  { displayText: buttonLabel, url },
          },
        ],
      },
    });
  }

  // ── Template messages ─────────────────────────────────────────────────────

  /**
   * Send an approved WhatsApp template (text-only body params).
   * @param {string} to
   * @param {string} templateName    Approved template name
   * @param {string} languageCode    e.g. 'en', 'en_US', 'hi'
   * @param {Array<{type:'text',text:string}>} bodyParams   Body variable values
   */
  async sendTemplate(to, templateName, languageCode, bodyParams = []) {
    return this._send(to, {
      type:     'Template',
      template: {
        name:     templateName,
        language: { code: languageCode },
        components: bodyParams.length
          ? [{ type: 'body', parameters: bodyParams }]
          : [],
      },
    });
  }

  /**
   * Send a template with a media header (image / document / video).
   * @param {string} to
   * @param {string} templateName
   * @param {string} languageCode
   * @param {{ type:'image'|'document'|'video', url:string }} headerMedia
   * @param {Array<{type:'text',text:string}>} bodyParams
   */
  async sendTemplateWithMedia(to, templateName, languageCode, headerMedia, bodyParams = []) {
    const components = [];

    // Header component
    components.push({
      type:       'header',
      parameters: [
        {
          type:              headerMedia.type,
          [headerMedia.type]: { link: headerMedia.url },
        },
      ],
    });

    if (bodyParams.length) {
      components.push({ type: 'body', parameters: bodyParams });
    }

    return this._send(to, {
      type:     'Template',
      template: {
        name:     templateName,
        language: { code: languageCode },
        components,
      },
    });
  }

  // ── Location ──────────────────────────────────────────────────────────────

  /**
   * Send a location pin.
   * @param {string} to
   * @param {number} latitude
   * @param {number} longitude
   * @param {string} [name]     Location name
   * @param {string} [address]  Address string
   */
  async sendLocation(to, latitude, longitude, name = '', address = '') {
    return this._send(to, {
      type: 'Location',
      data: { latitude, longitude, name, address },
    });
  }

  // ── Visitor-specific helpers ──────────────────────────────────────────────

  /**
   * Send visitor QR invitation via WhatsApp text + image.
   *
   * If a public QR image URL is provided the QR is sent as an image message.
   * Otherwise a rich text fallback is sent.
   *
   * @param {Object} opts
   * @param {string} opts.phone           Visitor's phone number
   * @param {string} opts.visitorName     Visitor display name
   * @param {string} opts.societyName     Society name
   * @param {string} opts.unitCode        Unit the visitor is coming to
   * @param {string} opts.hostName        Name of the inviting resident
   * @param {string} [opts.expectedArrival] Human-readable expected arrival
   * @param {string} opts.qrExpiresAt     Human-readable expiry
   * @param {string} [opts.qrImageUrl]    Public URL of QR image (optional)
   * @param {string} opts.qrToken         Raw token (fallback display)
   */
  async sendVisitorQr({
    phone,
    visitorName,
    societyName,
    unitCode,
    hostName,
    expectedArrival,
    qrExpiresAt,
    qrImageUrl,
    qrToken,
  }) {
    const arrivalLine = expectedArrival ? `\n📅 Expected arrival: ${expectedArrival}` : '';

    const textMsg =
`🏢 *${societyName}* — Visitor Pass

Hello *${visitorName}*! 👋

You have been invited to visit *Unit ${unitCode}* by *${hostName}*.${arrivalLine}
⏰ Valid until: ${qrExpiresAt}

🔑 Your entry token:
\`${qrToken}\`

Please show this message (or the QR code) to the security guard at the gate.

_This is a single-use pass. Do not share it._`;

    // Send text first (always)
    await this.sendText(phone, textMsg);

    // If we have a public image URL, also send the QR as an image
    if (qrImageUrl) {
      await this.sendImage(phone, qrImageUrl, `Visitor QR — ${societyName}`);
    }

    return true;
  }
}

// Export a singleton instance
module.exports = new WhatsAppService();
