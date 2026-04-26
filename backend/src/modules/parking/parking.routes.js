const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const checkPlanLimit = require('../../middleware/checkPlanLimit');
const c = require('./parking.controller');

router.use(auth);
router.use(checkPlanLimit('parking_management'));

const ADMIN = ['PRAMUKH', 'CHAIRMAN', 'VICE_CHAIRMAN', 'SECRETARY', 'ASSISTANT_SECRETARY'];
const STAFF = [...ADMIN, 'WATCHMAN'];

// ── Dashboard & Map ────────────────────────────────────────────────────────
router.get('/dashboard', c.getDashboard);
router.get('/map', c.getParkingMap);

// ── Slot Management ────────────────────────────────────────────────────────
router.get('/slots', c.listSlots);
router.get('/slots/available', c.listAvailableSlots);
router.get('/slots/:id', c.getSlot);
router.post('/slots', roleGuard(ADMIN), c.createSlot);
router.post('/slots/bulk', roleGuard(ADMIN), c.bulkCreateSlots);
router.patch('/slots/:id', roleGuard(ADMIN), c.updateSlot);
router.delete('/slots/:id', roleGuard(ADMIN), c.deleteSlot);

// ── Allotment Management ───────────────────────────────────────────────────
router.get('/allotments', roleGuard(ADMIN), c.listAllotments);
router.get('/allotments/unit/:unitId', c.listAllotmentsByUnit);
router.post('/allotments', roleGuard(ADMIN), c.createAllotment);
router.patch('/allotments/:id/vehicle', roleGuard(ADMIN), c.updateAllotmentVehicle);
router.patch('/allotments/:id/release', roleGuard(ADMIN), c.releaseAllotment);
router.patch('/allotments/:id/transfer', roleGuard(ADMIN), c.transferAllotment);
router.patch('/allotments/:id/suspend', roleGuard(ADMIN), c.suspendAllotment);
router.patch('/allotments/:id/reinstate', roleGuard(ADMIN), c.reinstateAllotment);

// ── Visitor/Guest Sessions ─────────────────────────────────────────────────
router.get('/sessions', roleGuard(STAFF), c.listSessions);
router.get('/sessions/overstayed', roleGuard(STAFF), c.listOverstayedSessions);
router.post('/sessions', roleGuard(STAFF), c.logEntry);
router.patch('/sessions/:id/exit', roleGuard(STAFF), c.logExit);

// ── Parking Charges ────────────────────────────────────────────────────────
router.get('/charges', roleGuard(ADMIN), c.listCharges);
router.post('/charges', roleGuard(ADMIN), c.createCharge);
router.post('/charges/generate', roleGuard(ADMIN), c.generateMonthlyCharges);
router.patch('/charges/:id/pay', roleGuard(ADMIN), c.payCharge);

module.exports = router;
