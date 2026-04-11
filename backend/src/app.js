require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');

const app = express();

// ── CORS — allow Flutter web (any localhost port) ─────────────────
app.use((req, res, next) => {
  const origin = req.headers.origin || '';
  if (origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use(bodyParser.json());

// ── Routes ────────────────────────────────────────────────────────
app.use('/api/auth',          require('./modules/auth/auth.routes'));
app.use('/api/members',       require('./modules/members/members.routes'));
app.use('/api/bills',         require('./modules/bills/bills.routes'));
app.use('/api/expenses',      require('./modules/expenses/expenses.routes'));
app.use('/api/complaints',    require('./modules/complaints/complaints.routes'));
app.use('/api/visitors',      require('./modules/visitors/visitors.routes'));
app.use('/api/notices',       require('./modules/notices/notices.routes'));
app.use('/api/amenities',     require('./modules/amenities/amenities.routes'));
app.use('/api/notifications', require('./modules/notifications/notifications.routes'));
app.use('/api/staff',         require('./modules/staff/staff.routes'));
app.use('/api/gatepasses',    require('./modules/gatepasses/gatepasses.routes'));
app.use('/api/domestichelp',  require('./modules/domestichelp/domestichelp.routes'));
app.use('/api/deliveries',    require('./modules/deliveries/deliveries.routes'));
app.use('/api/vehicles',      require('./modules/vehicles/vehicles.routes'));
app.use('/api/moverequests',  require('./modules/moverequests/moverequests.routes'));
app.use('/api/dashboard',     require('./modules/dashboard/dashboard.routes'));
app.use('/api/plans',         require('./modules/plans/plans.routes'));
app.use('/api/societies',     require('./modules/societies/societies.routes'));
app.use('/api/units',         require('./modules/units/units.routes'));
app.use('/api/subscriptions', require('./modules/subscriptions/subscriptions.routes'));
app.use('/api/superadmin',    require('./modules/superadmin/superadmin.routes'));
app.use('/api/users',         require('./modules/users/users.routes'));

// ── Health check ──────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Run this to free it:`);
    console.error(`  powershell -Command "Get-NetTCPConnection -LocalPort ${PORT} | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"`);
    process.exit(1);
  } else {
    throw err;
  }
});
