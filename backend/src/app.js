require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();

// ── CORS — allow Flutter web + mobile app ─────────────────────────
app.use((req, res, next) => {
  const origin = req.headers.origin || '';
  // Allow localhost (web dev) and any LAN IP (mobile dev), or no origin (native mobile)
  if (
    !origin ||
    origin.startsWith('http://localhost') ||
    origin.startsWith('http://127.0.0.1') ||
    origin.startsWith('http://192.168.') ||
    origin.includes('trycloudflare.com')
  ) {
    res.setHeader('Access-Control-Allow-Origin', origin || '*');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use(express.static(path.join(__dirname, '../public')));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use(bodyParser.json());

// Logger for debugging
app.use((req, res, next) => {
  console.log(`[DEBUG] ${req.method} ${req.url}`);
  next();
});

// ── Routes ────────────────────────────────────────────────────────
app.use('/api/auth', require('./modules/auth/auth.routes'));
app.use('/api/members', require('./modules/members/members.routes'));
app.use('/api/bills', require('./modules/bills/bills.routes'));
app.use('/api/expenses', require('./modules/expenses/expenses.routes'));
app.use('/api/complaints', require('./modules/complaints/complaints.routes'));
app.use('/api/visitors', require('./modules/visitors/visitors.routes'));
app.use('/api/notices', require('./modules/notices/notices.routes'));
app.use('/api/amenities', require('./modules/amenities/amenities.routes'));
app.use('/api/notifications', require('./modules/notifications/notifications.routes'));
app.use('/api/staff', require('./modules/staff/staff.routes'));
app.use('/api/gatepasses', require('./modules/gatepasses/gatepasses.routes'));
app.use('/api/domestichelp', require('./modules/domestichelp/domestichelp.routes'));
app.use('/api/deliveries', require('./modules/deliveries/deliveries.routes'));
app.use('/api/vehicles', require('./modules/vehicles/vehicles.routes'));
app.use('/api/moverequests', require('./modules/moverequests/moverequests.routes'));
app.use('/api/dashboard', require('./modules/dashboard/dashboard.routes'));
app.use('/api/plans', require('./modules/plans/plans.routes'));
app.use('/api/societies', require('./modules/societies/societies.routes'));
app.use('/api/units', require('./modules/units/units.routes'));
app.use('/api/gates', require('./modules/gates/gates.routes'));
app.use('/api/subscriptions', require('./modules/subscriptions/subscriptions.routes'));
app.use('/api/settings', require('./modules/settings/settings.routes'));
app.use('/api/payments', require('./modules/payments/payments.routes'));
app.use('/api/superadmin', require('./modules/superadmin/superadmin.routes'));
app.use('/api/users', require('./modules/users/users.routes'));
app.use('/api/parking', require('./modules/parking/parking.routes'));
app.use('/api/donations', require('./modules/donations/donations.routes'));
app.use('/api/reports', require('./modules/reports/reports.routes'));
app.use('/api/search', require('./modules/search/search.routes'));

// ── Health check ──────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ── Global error handler ──────────────────────────────────────────
// Must be last — catches all next(err) calls from routes
app.use((err, _req, res, _next) => {
  console.error('[ERROR]', err.message, err.stack?.split('\n')[1]);
  const status = err.status || err.statusCode || 500;
  res.status(status).json({ success: false, message: err.message || 'Internal server error' });
});

module.exports = app;

