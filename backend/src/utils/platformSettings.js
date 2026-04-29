/**
 * platformSettings.js — Thin helper for reading/writing PlatformSetting rows.
 *
 * Usage:
 *   const { getSetting, getVisitorQrMaxHrs } = require('./platformSettings');
 *
 *   const maxHrs = await getVisitorQrMaxHrs();  // → 3 (default)
 */

const prisma = require('../config/db');

/** Defaults — used when the row doesn't exist yet. */
const DEFAULTS = {
  visitor_qr_max_hrs:    { value: '3',  label: 'Max QR Expiry (hours)', dataType: 'number' },
  app_name:              { value: 'SocietyPro', label: 'App Name', dataType: 'string' },
  app_tagline:           { value: 'Smart society management', label: 'App Tagline', dataType: 'string' },
  app_version:           { value: '1.0.0', label: 'App Version', dataType: 'string' },
  app_min_version:       { value: '1.0.0', label: 'Min Required Version (force update)', dataType: 'string' },
  app_android_url:       { value: '', label: 'Android Play Store URL', dataType: 'string' },
  app_ios_url:           { value: '', label: 'iOS App Store URL', dataType: 'string' },
  app_support_email:     { value: '', label: 'Support Email', dataType: 'string' },
  app_support_phone:     { value: '', label: 'Support Phone', dataType: 'string' },
  terms_and_conditions:  { value: '', label: 'Terms & Conditions (HTML)', dataType: 'html' },
};

/**
 * Get a single platform setting by key.
 * If the row is missing, upserts the default so it exists for next time.
 *
 * @param {string} key
 * @returns {Promise<string>} Raw string value
 */
async function getSetting(key) {
  try {
    const row = await prisma.platformSetting.findUnique({ where: { key } });
    if (row) return row.value;

    // Row missing — insert default and return it
    const def = DEFAULTS[key];
    if (!def) return null;

    await prisma.platformSetting.upsert({
      where: { key },
      update: {},
      create: { key, ...def, updatedBy: null },
    });
    return def.value;
  } catch (err) {
    console.error(`[PlatformSettings] getSetting(${key}) error:`, err.message);
    return DEFAULTS[key]?.value ?? null;
  }
}

/**
 * Get all platform settings as an array (for SA UI).
 * Ensures defaults exist for any missing keys.
 */
async function getAllSettings() {
  // Upsert defaults for any missing keys
  for (const [key, def] of Object.entries(DEFAULTS)) {
    await prisma.platformSetting.upsert({
      where: { key },
      update: {},
      create: { key, ...def, updatedBy: null },
    }).catch(() => {});
  }

  return prisma.platformSetting.findMany({ orderBy: { key: 'asc' } });
}

/**
 * Update a single platform setting.
 *
 * @param {string} key
 * @param {string} value   String value to store
 * @param {string} updatedBy  userId of the SA making the change
 */
async function updateSetting(key, value, updatedBy) {
  const def = DEFAULTS[key];
  return prisma.platformSetting.upsert({
    where: { key },
    update: { value: String(value), updatedBy },
    create: {
      key,
      value: String(value),
      label: def?.label ?? key,
      dataType: def?.dataType ?? 'string',
      updatedBy,
    },
  });
}

// ─── Typed helpers ────────────────────────────────────────────────────────────

async function getVisitorQrMaxHrs() {
  const raw = await getSetting('visitor_qr_max_hrs');
  const n   = parseInt(raw ?? '3', 10);
  return Number.isFinite(n) && n > 0 ? n : 3;
}

/**
 * Returns the public-facing app info bundle (no auth needed).
 */
async function getAppInfo() {
  const keys = ['app_name', 'app_tagline', 'app_version', 'app_min_version', 'app_android_url', 'app_ios_url', 'app_support_email', 'app_support_phone', 'terms_and_conditions'];
  const rows = await prisma.platformSetting.findMany({ where: { key: { in: keys } } });
  const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return {
    appName:           map['app_name']            ?? DEFAULTS.app_name.value,
    appTagline:        map['app_tagline']          ?? DEFAULTS.app_tagline.value,
    appVersion:        map['app_version']          ?? DEFAULTS.app_version.value,
    minVersion:        map['app_min_version']      ?? DEFAULTS.app_min_version.value,
    androidUrl:        map['app_android_url']      ?? DEFAULTS.app_android_url.value,
    iosUrl:            map['app_ios_url']           ?? DEFAULTS.app_ios_url.value,
    supportEmail:      map['app_support_email']    ?? DEFAULTS.app_support_email.value,
    supportPhone:      map['app_support_phone']    ?? DEFAULTS.app_support_phone.value,
    termsAndConditions:map['terms_and_conditions'] ?? DEFAULTS.terms_and_conditions.value,
  };
}

module.exports = { getSetting, getAllSettings, updateSetting, getVisitorQrMaxHrs, getAppInfo };
