const { sendNotification } = require('../notifications/notifications.service');

const SYSTEM_SENDER = null; // system-generated, no sender user

/**
 * Notify watchmen (WATCHMAN role) about an overstayed vehicle.
 */
async function notifyOverstay(societyId, session) {
  const plate = session.vehicle?.numberPlate ?? session.guestPlate ?? 'Unknown';
  const slotNumber = session.slot?.slotNumber ?? 'Unknown';
  const guestName = session.guestName ? ` (${session.guestName})` : '';

  const minutesOver = session.expectedExitAt
    ? Math.round((Date.now() - new Date(session.expectedExitAt).getTime()) / 60000)
    : null;
  const overText = minutesOver != null ? ` — ${minutesOver} min overdue` : '';

  await sendNotification(SYSTEM_SENDER, societyId, {
    targetType: 'role',
    targetId: 'WATCHMAN',
    title: '🚗 Overstayed Vehicle',
    body: `${plate}${guestName} in slot ${slotNumber}${overText}. Please check.`,
    type: 'PARKING',
    route: '/parking',
  });
}

/**
 * Notify a unit's residents when their slot is allotted.
 */
async function notifyAllotment(societyId, unitId, slotNumber, allottedById) {
  await sendNotification(allottedById, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title: '🅿️ Parking Slot Allotted',
    body: `Parking slot ${slotNumber} has been assigned to your unit.`,
    type: 'PARKING',
    route: '/parking',
    excludeUserId: allottedById,
  });
}

/**
 * Notify a unit's residents when their slot is released.
 */
async function notifyRelease(societyId, unitId, slotNumber, releasedById) {
  await sendNotification(releasedById, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title: '🅿️ Parking Slot Released',
    body: `Parking slot ${slotNumber} has been released from your unit.`,
    type: 'PARKING',
    route: '/parking',
    excludeUserId: releasedById,
  });
}

/**
 * Notify a unit's residents when their allotment is suspended.
 */
async function notifySuspension(societyId, unitId, slotNumber, actorId) {
  await sendNotification(actorId, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title: '🅿️ Parking Slot Suspended',
    body: `Your access to parking slot ${slotNumber} has been temporarily suspended. Contact the admin for details.`,
    type: 'PARKING',
    route: '/parking',
    excludeUserId: actorId,
  });
}

/**
 * Notify a unit's residents when their allotment is reinstated.
 */
async function notifyReinstatement(societyId, unitId, slotNumber, actorId) {
  await sendNotification(actorId, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title: '🅿️ Parking Slot Reinstated',
    body: `Your access to parking slot ${slotNumber} has been restored.`,
    type: 'PARKING',
    route: '/parking',
    excludeUserId: actorId,
  });
}

/**
 * Notify a unit when a new parking charge is generated.
 */
async function notifyCharge(societyId, unitId, slotNumber, amount) {
  await sendNotification(SYSTEM_SENDER, societyId, {
    targetType: 'unit',
    targetId: unitId,
    title: '💳 Parking Charge Due',
    body: `₹${Number(amount).toFixed(0)} parking charge for slot ${slotNumber} is now due.`,
    type: 'BILL',
    route: '/bills',
  });
}

module.exports = {
  notifyOverstay,
  notifyAllotment,
  notifyRelease,
  notifySuspension,
  notifyReinstatement,
  notifyCharge,
};
