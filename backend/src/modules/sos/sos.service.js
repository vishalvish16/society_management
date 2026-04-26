const prisma = require('../../config/db');
const notificationsService = require('../notifications/notifications.service');

async function triggerSos(actor, { unitId, message }) {
  const { societyId } = actor;
  if (!societyId) {
    throw Object.assign(new Error('Society context missing'), { status: 400 });
  }

  const unit = await prisma.unit.findUnique({
    where: { id: unitId },
    select: { id: true, societyId: true, fullCode: true },
  });
  if (!unit || unit.societyId !== societyId) {
    throw Object.assign(new Error('Unit not found in your society'), { status: 404 });
  }

  const actorName = actor?.name || 'Security';
  const actorRole = actor?.role || 'WATCHMAN';
  const unitCode = unit.fullCode || '-';

  const title = 'SOS Emergency';
  const msg = message ? String(message).trim() : '';
  const body = (msg.length > 0)
    ? `Unit ${unitCode}: ${msg}`
    : `Emergency alert for Unit ${unitCode}. Please respond immediately.`;

  // Store as MANUAL (enum-safe), but push as SOS so the app shows a call-like alert.
  const notification = await notificationsService.sendNotification(actor.id, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title,
    body,
    type: 'MANUAL',
    route: `/sos?unitId=${encodeURIComponent(unitId)}&unitCode=${encodeURIComponent(unitCode)}&actorName=${encodeURIComponent(actorName)}&actorRole=${encodeURIComponent(actorRole)}`,
    pushType: 'SOS',
    pushData: {
      unitId,
      unitCode,
      actorId: actor.id,
      actorName,
      actorRole,
      message: msg,
    },
  });

  return { notificationId: notification.id };
}

async function acknowledgeSos(user, { notificationId }) {
  if (!notificationId) return { ok: true };
  // Mark as read so it doesn’t keep showing as unseen in history.
  await prisma.notificationRead.upsert({
    where: { notificationId_userId: { notificationId, userId: user.id } },
    update: { readAt: new Date() },
    create: { notificationId, userId: user.id },
  });
  return { ok: true };
}

module.exports = { triggerSos, acknowledgeSos };

