const prisma = require('../../config/db');
const { pushToTokens } = require('../../utils/push');

async function listNotifications(societyId, filters = {}) {
  const { page = 1, limit = 20 } = filters;
  const skip = (parseInt(page) - 1) * parseInt(limit);
  const [notifications, total] = await Promise.all([
    prisma.notification.findMany({
      where: { societyId },
      include: { sender: { select: { id: true, name: true } } },
      skip,
      take: parseInt(limit, 10),
      orderBy: { sentAt: 'desc' },
    }),
    prisma.notification.count({ where: { societyId } }),
  ]);
  return { notifications, total, page: parseInt(page, 10), limit: parseInt(limit, 10) };
}

async function sendNotification(senderId, societyId, data) {
  let { targetType, targetId, title, body, type, route } = data;
  const normalizedTarget = targetType?.toLowerCase();
  if (!['all', 'role', 'unit', 'user'].includes(normalizedTarget)) {
    throw Object.assign(new Error('targetType must be all, role, unit, or user'), { status: 400 });
  }

  // Normalize Notification Type for Prisma Enum
  const typeMapping = {
    'NOTICE_NEW':       'ANNOUNCEMENT',
    'NOTICE_UPDATE':    'ANNOUNCEMENT',
    'BILL_GENERATED':   'BILL',
    'BILL_PAID':        'PAYMENT',
    'EXPENSE_NEW':      'EXPENSE',
    'EXPENSE_UPDATE':   'EXPENSE',
    'VISITOR_CHECKIN':  'VISITOR',
    'VISITOR_PREAUTH':  'VISITOR',
    'COMPLAINT_NEW':    'COMPLAINT',
    'COMPLAINT_UPDATE': 'COMPLAINT',
    'DELIVERY_NEW':     'DELIVERY',
    'DELIVERY_UPDATE':  'DELIVERY'
  };
  const dbType = typeMapping[type] || type;

  return prisma.$transaction(async (tx) => {
    const notification = await tx.notification.create({
      data: {
        societyId,
        sentById: senderId || null,
        targetType: normalizedTarget,
        targetId: targetId || null,
        title,
        body,
        type: dbType,
      },
    });

    // Resolve FCM tokens
    let users = [];
    if (normalizedTarget === 'all') {
      users = await tx.user.findMany({
        where: { societyId, fcmToken: { not: null }, deletedAt: null, isActive: true },
        select: { id: true, fcmToken: true },
      });
    } else if (normalizedTarget === 'role') {
      users = await tx.user.findMany({
        where: { societyId, role: targetId, fcmToken: { not: null }, deletedAt: null, isActive: true },
        select: { id: true, fcmToken: true },
      });
    } else if (normalizedTarget === 'unit') {
      const residents = await tx.unitResident.findMany({
        where: { unitId: targetId, user: { societyId, fcmToken: { not: null }, deletedAt: null } },
        include: { user: { select: { id: true, fcmToken: true } } },
      });
      users = residents.map((r) => r.user);
    } else if (normalizedTarget === 'user') {
      const u = await tx.user.findUnique({
        where: { id: targetId },
        select: { id: true, fcmToken: true },
      });
      if (u?.fcmToken) users = [u];
    }

    // Exclude specific user if requested
    if (data.excludeUserId) {
      users = users.filter(u => u.id !== data.excludeUserId);
    }

    const tokens = users.map((u) => u.fcmToken).filter(Boolean);
    if (tokens.length > 0) {
      const pushData = { type, notificationId: notification.id };
      if (route) pushData.route = route;
      // Fire-and-forget — don't block transaction
      setImmediate(() => pushToTokens(tokens, { title, body, data: pushData }));
    }

    return notification;
  });
}

async function getNotificationsForUser(userId, societyId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true, unitResidents: { select: { unitId: true } } },
  });
  if (!user) return [];
  const unitIds = user.unitResidents.map((ur) => ur.unitId);

  return prisma.notification.findMany({
    where: {
      societyId,
      OR: [
        { targetType: 'all' },
        { targetType: 'role', targetId: user.role },
        ...(unitIds.length ? [{ targetType: 'unit', targetId: { in: unitIds } }] : []),
        { targetType: 'user', targetId: userId },
      ],
    },
    include: {
      sender: { select: { id: true, name: true } },
    },
    orderBy: { sentAt: 'desc' },
    take: 50,
  });
}

module.exports = { listNotifications, sendNotification, getNotificationsForUser };
