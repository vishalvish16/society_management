const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const notificationsService = require('../notifications/notifications.service');

function isAdminRole(role) {
  const r = String(role || '').toUpperCase();
  return r === 'PRAMUKH' || r === 'CHAIRMAN' || r === 'SECRETARY';
}

// ── Create Event ─────────────────────────────────────────────────────────────

async function createEvent(req, res) {
  try {
    const { societyId, id: createdById, role } = req.user;
    if (!isAdminRole(role)) return sendError(res, 'Insufficient permissions', 403);

    const {
      title, description, startDate, endDate, location,
      rules, organizerName, organizerContact,
      maxMembersPerRegistration, maxTotalRegistrations,
    } = req.body || {};

    if (!title || String(title).trim().length < 3) {
      return sendError(res, 'Title is required (min 3 chars)', 400);
    }
    if (!startDate || !endDate) return sendError(res, 'Start date and end date are required', 400);

    const start = new Date(startDate);
    const end = new Date(endDate);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return sendError(res, 'Invalid date format', 400);
    }
    if (end <= start) return sendError(res, 'End date must be after start date', 400);

    if (!location || String(location).trim().length < 2) {
      return sendError(res, 'Location is required', 400);
    }
    if (!organizerName || !organizerContact) {
      return sendError(res, 'Organizer name and contact are required', 400);
    }

    const event = await prisma.event.create({
      data: {
        societyId,
        createdById,
        title: String(title).trim(),
        description: description ? String(description).trim() : null,
        startDate: start,
        endDate: end,
        location: String(location).trim(),
        rules: rules ? String(rules).trim() : null,
        organizerName: String(organizerName).trim(),
        organizerContact: String(organizerContact).trim(),
        maxMembersPerRegistration: parseInt(maxMembersPerRegistration) || 5,
        maxTotalRegistrations: maxTotalRegistrations ? parseInt(maxTotalRegistrations) : null,
      },
      include: {
        creator: { select: { id: true, name: true } },
        _count: { select: { registrations: true } },
      },
    });

    // Save attachments if uploaded
    if (req.files && req.files.length > 0) {
      const attachmentsData = req.files.map((f) => ({
        eventId: event.id,
        fileName: f.originalname,
        fileType: f.mimetype,
        fileSize: f.size,
        fileUrl: `/uploads/events/${f.filename}`,
      }));
      await prisma.eventAttachment.createMany({ data: attachmentsData });
      event.attachments = await prisma.eventAttachment.findMany({ where: { eventId: event.id } });
    }

    // Single broadcast notification to all society members
    setImmediate(() => {
      notificationsService
        .sendNotification(createdById, societyId, {
          targetType: 'all',
          targetId: null,
          title: 'New Event',
          body: `${event.title} — ${start.toLocaleDateString()}`,
          type: 'MANUAL',
          route: `/events/${event.id}`,
        })
        .catch(() => {});
    });

    return sendSuccess(res, event, 'Event created', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── List Events ──────────────────────────────────────────────────────────────

async function listEvents(req, res) {
  try {
    const { societyId } = req.user;
    const { status, page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const where = { societyId };
    if (status) where.status = String(status).toUpperCase();

    const [events, total] = await Promise.all([
      prisma.event.findMany({
        where,
        skip,
        take: parseInt(limit),
        include: {
          creator: { select: { id: true, name: true } },
          attachments: true,
          _count: { select: { registrations: { where: { status: 'REGISTERED' } } } },
          registrations: {
            where: { userId: req.user.id, status: 'REGISTERED' },
            select: { id: true, memberCount: true, status: true },
            take: 1,
          },
        },
        orderBy: { startDate: 'desc' },
      }),
      prisma.event.count({ where }),
    ]);

    const data = events.map((e) => ({
      ...e,
      myRegistration: e.registrations?.[0] || null,
      registrations: undefined,
      registeredCount: e._count?.registrations ?? 0,
    }));

    return sendSuccess(res, { events: data, total, page: parseInt(page), limit: parseInt(limit) }, 'Events retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Get Event by ID ──────────────────────────────────────────────────────────

async function getEventById(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;

    const event = await prisma.event.findUnique({
      where: { id },
      include: {
        creator: { select: { id: true, name: true } },
        attachments: true,
        _count: { select: { registrations: { where: { status: 'REGISTERED' } } } },
        registrations: {
          where: { userId, status: 'REGISTERED' },
          select: { id: true, memberCount: true, notes: true, status: true, createdAt: true },
          take: 1,
        },
      },
    });
    if (!event || event.societyId !== societyId) return sendError(res, 'Event not found', 404);

    // Compute total registered members
    const totalMembers = await prisma.eventRegistration.aggregate({
      where: { eventId: id, status: 'REGISTERED' },
      _sum: { memberCount: true },
    });

    return sendSuccess(res, {
      ...event,
      myRegistration: event.registrations?.[0] || null,
      registrations: undefined,
      registeredCount: event._count?.registrations ?? 0,
      totalRegisteredMembers: totalMembers._sum?.memberCount ?? 0,
    });
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Update Event ─────────────────────────────────────────────────────────────

async function updateEvent(req, res) {
  try {
    const { societyId, role } = req.user;
    if (!isAdminRole(role)) return sendError(res, 'Insufficient permissions', 403);

    const { id } = req.params;
    const event = await prisma.event.findUnique({ where: { id } });
    if (!event || event.societyId !== societyId) return sendError(res, 'Event not found', 404);

    const {
      title, description, startDate, endDate, location,
      rules, organizerName, organizerContact,
      maxMembersPerRegistration, maxTotalRegistrations, status,
    } = req.body || {};

    const updateData = {};
    if (title !== undefined) updateData.title = String(title).trim();
    if (description !== undefined) updateData.description = description ? String(description).trim() : null;
    if (startDate !== undefined) updateData.startDate = new Date(startDate);
    if (endDate !== undefined) updateData.endDate = new Date(endDate);
    if (location !== undefined) updateData.location = String(location).trim();
    if (rules !== undefined) updateData.rules = rules ? String(rules).trim() : null;
    if (organizerName !== undefined) updateData.organizerName = String(organizerName).trim();
    if (organizerContact !== undefined) updateData.organizerContact = String(organizerContact).trim();
    if (maxMembersPerRegistration !== undefined) updateData.maxMembersPerRegistration = parseInt(maxMembersPerRegistration) || 5;
    if (maxTotalRegistrations !== undefined) updateData.maxTotalRegistrations = maxTotalRegistrations ? parseInt(maxTotalRegistrations) : null;
    if (status !== undefined) updateData.status = String(status).toUpperCase();

    // Save new attachments if uploaded
    if (req.files && req.files.length > 0) {
      const attachmentsData = req.files.map((f) => ({
        eventId: id,
        fileName: f.originalname,
        fileType: f.mimetype,
        fileSize: f.size,
        fileUrl: `/uploads/events/${f.filename}`,
      }));
      await prisma.eventAttachment.createMany({ data: attachmentsData });
    }

    const updated = await prisma.event.update({
      where: { id },
      data: updateData,
      include: {
        creator: { select: { id: true, name: true } },
        attachments: true,
        _count: { select: { registrations: { where: { status: 'REGISTERED' } } } },
      },
    });

    return sendSuccess(res, updated, 'Event updated');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Delete Event ─────────────────────────────────────────────────────────────

async function deleteEvent(req, res) {
  try {
    const { societyId, role } = req.user;
    if (!isAdminRole(role)) return sendError(res, 'Insufficient permissions', 403);

    const { id } = req.params;
    const event = await prisma.event.findUnique({ where: { id } });
    if (!event || event.societyId !== societyId) return sendError(res, 'Event not found', 404);

    await prisma.event.delete({ where: { id } });
    return sendSuccess(res, null, 'Event deleted');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Register for Event ───────────────────────────────────────────────────────

async function registerForEvent(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;
    const { memberCount, notes } = req.body || {};

    const event = await prisma.event.findUnique({
      where: { id },
      include: {
        _count: { select: { registrations: { where: { status: 'REGISTERED' } } } },
      },
    });
    if (!event || event.societyId !== societyId) return sendError(res, 'Event not found', 404);

    if (event.status === 'CANCELLED') return sendError(res, 'This event has been cancelled', 400);
    if (event.status === 'COMPLETED') return sendError(res, 'This event has already ended', 400);

    const count = parseInt(memberCount) || 1;
    if (count < 1) return sendError(res, 'Member count must be at least 1', 400);
    if (count > event.maxMembersPerRegistration) {
      return sendError(res, `Maximum ${event.maxMembersPerRegistration} members per registration`, 400);
    }

    // Check capacity
    if (event.maxTotalRegistrations) {
      const currentCount = event._count?.registrations ?? 0;
      if (currentCount >= event.maxTotalRegistrations) {
        return sendError(res, 'Event is full. No more registrations available.', 400);
      }
    }

    const registration = await prisma.eventRegistration.create({
      data: {
        eventId: id,
        userId,
        memberCount: count,
        notes: notes ? String(notes).trim() : null,
      },
      include: {
        user: { select: { id: true, name: true, phone: true } },
      },
    });

    // Notify event creator
    setImmediate(() => {
      notificationsService
        .sendNotification(userId, societyId, {
          targetType: 'user',
          targetId: event.createdById,
          title: 'New Event Registration',
          body: `${registration.user.name} registered for "${event.title}" (${count} members)`,
          type: 'MANUAL',
          route: `/events/${event.id}`,
        })
        .catch(() => {});
    });

    return sendSuccess(res, registration, 'Registered successfully', 201);
  } catch (err) {
    if (String(err.code) === 'P2002') {
      return sendError(res, 'You have already registered for this event', 400);
    }
    return sendError(res, err.message, err.status || 500);
  }
}

// ── Cancel Registration ──────────────────────────────────────────────────────

async function cancelRegistration(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;

    const event = await prisma.event.findUnique({ where: { id } });
    if (!event || event.societyId !== societyId) return sendError(res, 'Event not found', 404);

    const registration = await prisma.eventRegistration.findUnique({
      where: { eventId_userId: { eventId: id, userId } },
    });
    if (!registration || registration.status === 'CANCELLED') {
      return sendError(res, 'No active registration found', 404);
    }

    const updated = await prisma.eventRegistration.update({
      where: { id: registration.id },
      data: { status: 'CANCELLED' },
    });

    return sendSuccess(res, updated, 'Registration cancelled');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// ── View Registrations (admin / creator) ─────────────────────────────────────

async function getRegistrations(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const event = await prisma.event.findUnique({ where: { id } });
    if (!event || event.societyId !== societyId) return sendError(res, 'Event not found', 404);

    if (!isAdminRole(role) && event.createdById !== userId) {
      return sendError(res, 'Only admin or event creator can view registrations', 403);
    }

    const registrations = await prisma.eventRegistration.findMany({
      where: { eventId: id },
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, role: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const totalMembers = registrations
      .filter((r) => r.status === 'REGISTERED')
      .reduce((sum, r) => sum + r.memberCount, 0);

    return sendSuccess(res, {
      registrations,
      totalRegistered: registrations.filter((r) => r.status === 'REGISTERED').length,
      totalMembers,
      totalCancelled: registrations.filter((r) => r.status === 'CANCELLED').length,
    }, 'Registrations retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = {
  createEvent,
  listEvents,
  getEventById,
  updateEvent,
  deleteEvent,
  registerForEvent,
  cancelRegistration,
  getRegistrations,
};
