require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');
const helmet = require('helmet');
const hpp = require('hpp');
const { generalApiLimiter } = require('./middleware/rateLimiter');

const app = express();

// ── Reverse proxy support (required for rate limiting) ─────────────
// If you deploy behind a reverse proxy/load balancer that sets X-Forwarded-For,
// Express must trust the proxy so express-rate-limit can identify clients.
// Configure explicitly via TRUST_PROXY (recommended), otherwise default to 1 hop in production.
const trustProxyEnv = process.env.TRUST_PROXY;
if (typeof trustProxyEnv === 'string' && trustProxyEnv.trim() !== '') {
  const v = trustProxyEnv.trim().toLowerCase();
  if (v === 'true' || v === '1') app.set('trust proxy', 1);
  else if (v === 'false' || v === '0') app.set('trust proxy', false);
  else if (!Number.isNaN(Number(v))) app.set('trust proxy', Number(v));
  else app.set('trust proxy', trustProxyEnv);
} else if (process.env.NODE_ENV === 'production') {
  app.set('trust proxy', 1);
}

// ── Security headers ──────────────────────────────────────────────
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'same-site' },
  contentSecurityPolicy: false, // Configured separately if needed for web dashboards
}));

// ── CORS — strict whitelist only ──────────────────────────────────
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

// Always allow localhost in development
if (process.env.NODE_ENV !== 'production') {
  ALLOWED_ORIGINS.push('http://localhost:3000', 'http://localhost:3001', 'http://127.0.0.1:3000');
}

function isDevLocalhostOrigin(origin) {
  if (!origin) return false;
  // Allow localhost origins in non-prod by default. In production, allow only if explicitly enabled.
  const allowLocalhostInProd = String(process.env.ALLOW_LOCALHOST_ORIGINS || '').toLowerCase() === 'true';
  if (process.env.NODE_ENV === 'production' && !allowLocalhostInProd) return false;
  try {
    const u = new URL(origin);
    const isLocalHost = u.hostname === 'localhost' || u.hostname === '127.0.0.1';
    const isHttp = u.protocol === 'http:' || u.protocol === 'https:';
    return isHttp && isLocalHost;
  } catch (_) {
    return false;
  }
}

app.use((req, res, next) => {
  const origin = req.headers.origin || '';
  const allowed = !origin || ALLOWED_ORIGINS.includes(origin) || isDevLocalhostOrigin(origin);
  if (allowed) {
    if (origin) res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  }
  if (req.method === 'OPTIONS') {
    // Preflight must include CORS headers; otherwise browsers will block.
    return allowed ? res.sendStatus(204) : res.sendStatus(403);
  }
  next();
});

// ── HTTP Parameter Pollution protection ───────────────────────────
app.use(hpp());

// ── Body size limits ──────────────────────────────────────────────
app.use(bodyParser.json({ limit: '10kb' }));
app.use(bodyParser.urlencoded({ limit: '10kb', extended: false }));

// ── Static public assets (non-sensitive) ─────────────────────────
app.use(express.static(path.join(__dirname, '../public')));

// ── Public uploads (images, receipts, attachments) ────────────────
// Flutter Web image loading cannot attach Authorization headers, so
// we must serve uploaded files via a public URL path.
// DB stores paths like `/uploads/<folder>/<filename>`.
app.use(
  '/uploads',
  express.static(path.join(__dirname, '../uploads'), {
    fallthrough: false,
    maxAge: process.env.NODE_ENV === 'production' ? '1h' : 0,
    etag: true,
  })
);

// ── Authenticated file serving ────────────────────────────────────
// Uploads are NOT served statically — use /api/files/:folder/:filename
const authMiddleware = require('./middleware/auth');
const fs = require('fs');

app.get('/api/files/:folder/:filename', authMiddleware, (req, res) => {
  const { folder, filename } = req.params;
  // Prevent path traversal: strip any directory separators
  const safeFolder   = path.basename(folder);
  const safeFilename = path.basename(filename);
  const filePath = path.join(__dirname, '../uploads', safeFolder, safeFilename);
  if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, message: 'File not found' });
  res.sendFile(filePath);
});

// ── General API rate limiter (all routes) ─────────────────────────
app.use('/api/', generalApiLimiter);

// ── Suspension gate (all authenticated society-scoped routes) ─────
// Auth-optional: if token is present, check society suspension status.
// SUPER_ADMIN is always exempt. Public/auth routes are naturally exempt
// because req.user is not set at that point.
const checkSuspended = require('./middleware/checkSuspended');
app.use('/api/', (req, res, next) => {
  // Only activate when we have a decoded user (token already validated upstream per-route)
  // We re-check lazily so public routes (/api/plans/public, /api/auth/*) are unaffected.
  if (!req.user) return next();
  return checkSuspended(req, res, next);
});

// ── Routes ────────────────────────────────────────────────────────
app.use('/api/auth', require('./modules/auth/auth.routes'));
app.use('/api/members', require('./modules/members/members.routes'));
app.use('/api/bills', require('./modules/bills/bills.routes'));
app.use('/api/expenses', require('./modules/expenses/expenses.routes'));
app.use('/api/complaints', require('./modules/complaints/complaints.routes'));
app.use('/api/suggestions', require('./modules/suggestions/suggestions.routes'));
app.use('/api/visitors', require('./modules/visitors/visitors.routes'));
app.use('/api/notices', require('./modules/notices/notices.routes'));
app.use('/api/amenities', require('./modules/amenities/amenities.routes'));
app.use('/api/notifications', require('./modules/notifications/notifications.routes'));
app.use('/api/sos', require('./modules/sos/sos.routes'));
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
app.use('/api/chat',   require('./modules/chat/chat.routes'));
app.use('/api/polls',  require('./modules/polls/polls.routes'));
app.use('/api/events', require('./modules/events/events.routes'));
app.use('/api/rentals', require('./modules/rentals/rentals.routes'));
app.use('/api/tasks',   require('./modules/tasks/tasks.routes'));
app.use('/api/rules',   require('./modules/rules/rules.routes'));
app.use('/api/assets',  require('./modules/assets/assets.routes'));
app.use('/api/wall',   require('./modules/wall/wall.routes'));
app.use('/api/app-info', require('./modules/appinfo/appinfo.routes'));
app.use('/api/estimates', require('./modules/estimates/estimates.routes'));

// ── Health check ──────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ── Global error handler ──────────────────────────────────────────
app.use((err, _req, res, _next) => {
  // Always log the full error server-side
  console.error('[ERROR]', err.message, err.stack?.split('\n')[1]);
  const status = err.status || err.statusCode || 500;

  // Never expose internal error details to clients in production
  const message = process.env.NODE_ENV === 'production'
    ? (status < 500 ? err.message : 'Internal server error')
    : (err.message || 'Internal server error');

  res.status(status).json({ success: false, message });
});

module.exports = app;
