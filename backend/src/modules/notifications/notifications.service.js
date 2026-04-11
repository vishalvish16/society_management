const prisma = require('../../config/db');

/**
 * List notification history for a society.
 */
async function listNotifications(societyId, filters = {}) {
  const { page = 1, limit = 20 } = filters;
  const skip = (page - 1) * limit;

  const [notifications, total] = await Promise.all([
    prisma.notification.findMany({
      where: { societyId },
      include: {
        sender: { select: { name: true } }
      },
      skip,
      take: parseInt(limit, 10),
      orderBy: { sentAt: 'desc' }
    }),
    prisma.notification.count({ where: { societyId } })
  ]);

  return { notifications, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

/**
 * Send a notification to a target group.
 * @param {string|null} senderId - ID of the admin who sent it (null for system)
 * @param {string} societyId - The society ID
 * @param {{ targetType: string, targetId?: string, title: string, body: string, type: string }} data
 */
async function sendNotification(senderId, societyId, data) {
  const { targetType, targetId, title, body, type } = data;

  return prisma.$transaction(async (tx) => {
    // 1. Record in database
    const notification = await tx.notification.create({
      data: {
        societyId,
        sentBy: senderId,
        targetType,
        targetId,
        title,
        body,
        type
      }
    });

    // 2. Resolve target users to get FCM tokens
    let users = [];
    if (targetType === 'ALL') {
      users = await tx.user.findMany({
        where: { societyId, fcmToken: { not: null }, deletedAt: null },
        select: { fcmToken: true }
      });
    } else if (targetType === 'ROLE') {
      users = await tx.user.findMany({
        where: { societyId, role: targetId, fcmToken: { not: null }, deletedAt: null },
        select: { fcmToken: true }
      });
    } else if (targetType === 'UNIT') {
      const residents = await tx.unitResident.findMany({
        where: { unitId: targetId, user: { societyId, fcmToken: { not: null }, deletedAt: null } },
        include: { user: { select: { fcmToken: true } } }
      });
      users = residents.map(r => r.user);
    }

    const tokens = users.map(u => u.fcmToken).filter(Boolean);

    // 3. Trigger Push Notification (Simulated in this phase)
    if (tokens.length > 0) {
      console.log(`[PushService] Sending to ${tokens.length} tokens for ${societyId}: ${title}`);
      // TODO: Implement FCM Admin SDK integration
    }

    return notification;
  });
}

/**
 * Get recent notifications for a specific user.
 * (Looks at notifications where they are part of the target group).
 */
async function getNotificationsForUser(userId, societyId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true, unitResidents: { select: { unitId: true } } }
  });

  if (!user) return [];

  const unitIds = user.unitResidents.map(ur => ur.unitId);

  return prisma.notification.findMany({
    where: {
      societyId,
      OR: [
        { targetType: 'ALL' },
        { targetType: 'ROLE', targetId: user.role },
        { targetType: 'UNIT', targetId: { in: unitIds } }
      ]
    },
    orderBy: { sentAt: 'desc' },
    take: 50
  });
}

module.exports = {
  listNotifications,
  sendNotification,
  getNotificationsForUser
};
