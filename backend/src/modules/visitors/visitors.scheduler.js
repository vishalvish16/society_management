const { PrismaClient } = require('@prisma/client');
const { sendNotification } = require('../notifications/notifications.service');
const { getIO } = require('../../socket');

const prisma = new PrismaClient();

const SYSTEM_SENDER_ID = null; // scheduler-initiated, no user sender

const RETRY_INTERVAL_MS = 3 * 60 * 1000; // resend every 3 minutes
const MAX_RETRIES = 3;                    // auto-deny after 3 retries
const CHECK_INTERVAL_MS = 60 * 1000;     // check every 60 seconds

async function processAwaitingApprovals() {
  try {
    const now = new Date();
    const cutoff = new Date(now.getTime() - RETRY_INTERVAL_MS);

    // Find AWAITING visitors that haven't been notified recently
    const visitors = await prisma.visitor.findMany({
      where: {
        approvalStatus: 'AWAITING',
        autoDeniedAt: null,
        OR: [
          { lastNotifiedAt: null },
          { lastNotifiedAt: { lte: cutoff } },
        ],
      },
      include: {
        unit: { include: { residents: { include: { user: true } } } },
        society: true,
      },
    });

    for (const visitor of visitors) {
      if (visitor.retryCount >= MAX_RETRIES) {
        // Auto-deny
        await prisma.visitor.update({
          where: { id: visitor.id },
          data: {
            approvalStatus: 'DENIED',
            autoDeniedAt: now,
          },
        });

        // Notify watchman room about auto-deny
        const io = getIO();
        if (io) {
          io.to(`society_${visitor.societyId}_watchman`).emit('walkin_auto_denied', {
            visitorId: visitor.id,
            visitorName: visitor.visitorName,
            unitId: visitor.unitId,
          });
        }

        // Push to watchman staff
        await sendNotification(SYSTEM_SENDER_ID, visitor.societyId, {
          targetType: 'role',
          targetId: 'WATCHMAN',
          title: '⛔ Visitor Auto-Denied',
          body: `${visitor.visitorName} was auto-denied after no response from resident.`,
          type: 'VISITOR_CHECKIN',
          route: '/visitors',
        });

        console.log(`[VisitorScheduler] Auto-denied visitor ${visitor.id} (${visitor.visitorName}) after ${visitor.retryCount} retries`);
        continue;
      }

      // Resend push to unit residents
      const retryNum = visitor.retryCount + 1;
      const remaining = MAX_RETRIES - retryNum;

      await sendNotification(SYSTEM_SENDER_ID, visitor.societyId, {
        targetType: 'unit',
        targetId: visitor.unitId,
        title: `🚨 Visitor Still Waiting (Reminder ${retryNum + 1})`,
        body: `${visitor.visitorName} is at the gate waiting for your response. ${remaining > 0 ? `${remaining} reminder(s) left before auto-deny.` : 'Last chance — will be auto-denied on next check.'}`,
        type: 'VISITOR_CHECKIN',
        route: '/visitors/pending-approvals',
      });

      await prisma.visitor.update({
        where: { id: visitor.id },
        data: {
          retryCount: { increment: 1 },
          lastNotifiedAt: now,
        },
      });

      console.log(`[VisitorScheduler] Retry ${retryNum} for visitor ${visitor.id} (${visitor.visitorName})`);
    }
  } catch (err) {
    console.error('[VisitorScheduler] Error:', err.message);
  }
}

function startVisitorApprovalJobs() {
  console.log('[VisitorScheduler] Started — checking every 60s, retrying every 3min, auto-deny after 3 retries');
  setInterval(processAwaitingApprovals, CHECK_INTERVAL_MS);
  // Run once at startup to catch any leftover from before restart
  processAwaitingApprovals();
}

module.exports = { startVisitorApprovalJobs };
