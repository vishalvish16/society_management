/**
 * push.js — Central FCM push notification utility.
 *
 * Usage:
 *   const { pushToUsers, pushToSociety, pushToUnit } = require('../../utils/push');
 *
 * All functions are fire-and-forget safe — they never throw.
 * They resolve quietly if Firebase is not configured.
 */

const { getFirebaseAdmin } = require('../config/firebase');
const prisma = require('../config/db');

/**
 * Send push to a list of FCM tokens.
 * @param {string[]} tokens
 * @param {{ title: string, body: string, data?: Record<string,string> }} payload
 * @param {{ excludeUserId?: string }} opts
 */
async function pushToTokens(tokens, { title, body, data = {} }, opts = {}) {
  if (!tokens || tokens.length === 0) return;
  const admin = getFirebaseAdmin();
  if (!admin) return; // Firebase not configured

  // Ensure all data values are strings (FCM requirement)
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v ?? '')])
  );

  try {
    const message = {
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'society_high_importance' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `[FCM] "${title}" → ${response.successCount}/${tokens.length} delivered, ${response.failureCount} failed`
    );

    // Clean up invalid tokens from DB
    response.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error?.code;
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          prisma.user
            .updateMany({ where: { fcmToken: tokens[i] }, data: { fcmToken: null } })
            .catch(() => {});
        }
      }
    });
  } catch (err) {
    console.error('[FCM] Send error:', err.message);
  }
}

/**
 * Push to specific user IDs.
 * @param {string[]} userIds
 * @param payload
 * @param {{ excludeUserId?: string }} opts
 */
async function pushToUsers(userIds, payload, opts = {}) {
  if (!userIds?.length) return;
  const filtered = opts.excludeUserId
    ? userIds.filter((id) => id !== opts.excludeUserId)
    : userIds;
  if (!filtered.length) return;
  const users = await prisma.user.findMany({
    where: { id: { in: filtered }, fcmToken: { not: null } },
    select: { fcmToken: true },
  });
  const tokens = users.map((u) => u.fcmToken).filter(Boolean);
  return pushToTokens(tokens, payload);
}

/**
 * Push to all members of a society.
 * @param {{ excludeUserId?: string }} opts
 */
async function pushToSociety(societyId, payload, opts = {}) {
  const where = { societyId, fcmToken: { not: null }, isActive: true, deletedAt: null };
  if (opts.excludeUserId) where.id = { not: opts.excludeUserId };
  const users = await prisma.user.findMany({ where, select: { fcmToken: true } });
  const tokens = users.map((u) => u.fcmToken).filter(Boolean);
  return pushToTokens(tokens, payload);
}

/**
 * Push to residents of a specific unit.
 * @param {{ excludeUserId?: string }} opts
 */
async function pushToUnit(unitId, payload, opts = {}) {
  const where = { unitId, user: { fcmToken: { not: null }, isActive: true } };
  if (opts.excludeUserId) where.userId = { not: opts.excludeUserId };
  const residents = await prisma.unitResident.findMany({
    where,
    include: { user: { select: { fcmToken: true } } },
  });
  const tokens = residents.map((r) => r.user.fcmToken).filter(Boolean);
  return pushToTokens(tokens, payload);
}

/**
 * Push to all members with a specific role in a society.
 * @param {{ excludeUserId?: string }} opts
 */
async function pushToRole(societyId, role, payload, opts = {}) {
  const where = { societyId, role, fcmToken: { not: null }, isActive: true, deletedAt: null };
  if (opts.excludeUserId) where.id = { not: opts.excludeUserId };
  const users = await prisma.user.findMany({ where, select: { fcmToken: true } });
  const tokens = users.map((u) => u.fcmToken).filter(Boolean);
  return pushToTokens(tokens, payload);
}

module.exports = { pushToTokens, pushToUsers, pushToSociety, pushToUnit, pushToRole };
