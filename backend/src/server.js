require('dotenv').config();

const app = require('./app');
const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const prisma = require('./config/db');
const { setIO } = require('./socket');
const { startBillingJobs } = require('./modules/bills/bills.scheduler');
const { startParkingJobs } = require('./modules/parking/parking.scheduler');
const { startVisitorApprovalJobs } = require('./modules/visitors/visitors.scheduler');

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    // Verify database connection
    await prisma.$connect();
    console.log('Database connected successfully');

    const server = http.createServer(app);

    // ── Socket.IO for real-time chat ─────────────────────────────────
    const SOCKET_ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
      .split(',').map(o => o.trim()).filter(Boolean);
    if (process.env.NODE_ENV !== 'production') {
      SOCKET_ALLOWED_ORIGINS.push('http://localhost:3000', 'http://localhost:3001', 'http://127.0.0.1:3000');
    }

    const io = new Server(server, {
      cors: {
        origin: (origin, cb) => {
          // Native mobile apps send no origin — allow them
          if (!origin || SOCKET_ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
          return cb(new Error('Socket origin not allowed'));
        },
        credentials: true,
      },
    });

    // Auth middleware — validate JWT on every socket connection
    io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth?.token || socket.handshake.query?.token;
        if (!token) return next(new Error('No token'));
        const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
        socket.userId = payload.id;
        socket.societyId = payload.societyId;
        next();
      } catch (err) {
        if (err.name === 'TokenExpiredError') return next(new Error('Token expired'));
        next(new Error('Invalid token'));
      }
    });

    io.on('connection', (socket) => {
      // Client joins a room channel to receive messages
      socket.on('join_room', (roomId) => {
        socket.join(roomId);
      });
      socket.on('leave_room', (roomId) => {
        socket.leave(roomId);
      });
      // Typing indicator (broadcast to others in room)
      socket.on('typing', ({ roomId, isTyping }) => {
        socket.to(roomId).emit('user_typing', { userId: socket.userId, isTyping });
      });
    });

    // Make io accessible in route handlers via req.app.get('io')
    app.set('io', io);
    // Also expose io for schedulers/services without req context
    setIO(io);

    server.listen(PORT, () => {
      console.log(`Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
    });

    startBillingJobs();
    startParkingJobs();
    startVisitorApprovalJobs();

    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.error(`Port ${PORT} is already in use. Run this to free it:`);
        console.error(`  powershell -Command "Get-NetTCPConnection -LocalPort ${PORT} | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"`);
        process.exit(1);
      } else {
        throw err;
      }
    });

  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

start();
