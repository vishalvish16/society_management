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
  visitor_qr_max_hrs: { value: '3', label: 'Max QR Expiry (hours)', dataType: 'number' },
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

/**
 * Returns the platform-wide maximum QR expiry in hours.
 * Default: 3 hours.
 */
async function getVisitorQrMaxHrs() {
  const raw = await getSetting('visitor_qr_max_hrs');
  const n   = parseInt(raw ?? '3', 10);
  return Number.isFinite(n) && n > 0 ? n : 3;
}

module.exports = { getSetting, getAllSettings, updateSetting, getVisitorQrMaxHrs };
