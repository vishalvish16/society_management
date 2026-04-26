const prisma = require('../../config/db');
const { notifyOverstay } = require('./parking.notifications');

let schedulerHandle = null;

/**
 * Finds sessions where expectedExitAt has passed and status is still ACTIVE.
 * Marks them OVERSTAYED and fires a push notification to all WATCHMAN users
 * in the society.
 *
 * Runs every 5 minutes. Fire-and-forget — errors are logged, never thrown.
 */
async function runOverstayCheck() {
  const now = new Date();

  // Find newly overstayed sessions (ACTIVE + expectedExitAt in the past)
  const overstayed = await prisma.parkingSession.findMany({
    where: {
      status: 'ACTIVE',
      expectedExitAt: { lt: now },
    },
    include: {
      slot: { select: { slotNumber: true } },
      vehicle: { select: { numberPlate: true, type: true } },
    },
  });

  if (overstayed.length === 0) return { marked: 0, notified: 0 };

  // Bulk mark as OVERSTAYED
  const ids = overstayed.map((s) => s.id);
  await prisma.parkingSession.updateMany({
    where: { id: { in: ids } },
    data: { status: 'OVERSTAYED' },
  });

  // Send one push notification per session (grouped per society to avoid spam)
  const societyBatches = new Map();
  for (const session of overstayed) {
    if (!societyBatches.has(session.societyId)) societyBatches.set(session.societyId, []);
    societyBatches.get(session.societyId).push(session);
  }

  let notified = 0;
  for (const [societyId, sessions] of societyBatches) {
    for (const session of sessions) {
      try {
        await notifyOverstay(societyId, session);
        notified++;
      } catch (err) {
        console.error(`[parking-jobs] overstay notify failed (session ${session.id}):`, err.message);
      }
    }
  }

  return { marked: overstayed.length, notified };
}

/**
 * Generates monthly parking charges (as maintenanceBill records) for all societies with active allotments.
 * Runs at server startup on the 1st of each month (checks if already generated).
 */
async function runMonthlyChargeGeneration() {
  const now = new Date();
  // Only run on the 1st of the month
  if (now.getDate() !== 1) return { skipped: true };

  const billingMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const dueDate = new Date(now.getFullYear(), now.getMonth(), 10); // due on the 10th
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
  const monthLabel = now.toLocaleString('en-IN', { month: 'long', year: 'numeric' });

  // Get all active allotments across all societies that have parking charges enabled
  const allotments = await prisma.parkingAllotment.findMany({
    where: { status: 'ACTIVE' },
    include: {
      slot: { select: { slotNumber: true } },
      society: { select: { settings: true } },
    },
  });

  let generated = 0;
  for (const allotment of allotments) {
    const settings = allotment.society?.settings || {};
    const monthlyRate = settings.parkingMonthlyRate;
    if (!monthlyRate || Number(monthlyRate) <= 0) continue;

    // Check if parking bill already exists for this month (in maintenanceBill)
    const existing = await prisma.maintenanceBill.findFirst({
      where: {
        unitId: allotment.unitId,
        societyId: allotment.societyId,
        category: 'PARKING',
        billingMonth: { gte: billingMonth, lte: monthEnd },
        deletedAt: null,
      },
    });
    if (existing) continue;

    await prisma.maintenanceBill.create({
      data: {
        societyId: allotment.societyId,
        unitId: allotment.unitId,
        billingMonth,
        amount: Number(monthlyRate),
        totalDue: Number(monthlyRate),
        status: 'PENDING',
        dueDate,
        title: 'Parking Charge',
        description: `Monthly parking charge — Slot ${allotment.slot.slotNumber} — ${monthLabel}`,
        category: 'PARKING',
      },
    });
    generated++;
  }

  return { generated };
}

function startParkingJobs() {
  if (process.env.NODE_ENV === 'test' || schedulerHandle) return;

  const runOverstay = async () => {
    try {
      const result = await runOverstayCheck();
      if (result.marked > 0) {
        console.log(`[parking-jobs] marked ${result.marked} session(s) as OVERSTAYED, notified ${result.notified}`);
      }
    } catch (err) {
      console.error('[parking-jobs] overstay check failed:', err.message);
    }
  };

  const runCharges = async () => {
    try {
      const result = await runMonthlyChargeGeneration();
      if (!result.skipped && result.generated > 0) {
        console.log(`[parking-jobs] generated ${result.generated} monthly parking charge(s)`);
      }
    } catch (err) {
      console.error('[parking-jobs] monthly charge generation failed:', err.message);
    }
  };

  // Run once shortly after boot
  setTimeout(() => {
    runOverstay();
    // Monthly charge generation is currently manual only per user preference
    // runCharges(); 
  }, 15 * 1000);

  // Overstay check every 5 minutes
  schedulerHandle = setInterval(runOverstay, 5 * 60 * 1000);

  // Monthly charge generation check removed per user preference to prevent accidental generation
  // setInterval(runCharges, 60 * 60 * 1000);
}

module.exports = { startParkingJobs, runOverstayCheck, runMonthlyChargeGeneration };
