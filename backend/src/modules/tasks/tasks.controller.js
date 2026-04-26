const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const notificationsService = require('../notifications/notifications.service');

const ADMIN_ROLES = ['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER'];

const TASK_CATEGORIES = {
  MAINTENANCE: {
    label: 'Maintenance',
    subCategories: [
      'Plumbing', 'Electrical', 'Painting', 'Civil Work', 'Lift/Elevator',
      'Water Tank', 'Generator', 'Fire Safety', 'Pest Control', 'CCTV/Intercom',
      'Garden/Landscaping', 'Other',
    ],
  },
  HOUSEKEEPING: {
    label: 'Housekeeping',
    subCategories: [
      'Common Area Cleaning', 'Staircase Cleaning', 'Lobby Cleaning',
      'Terrace Cleaning', 'Garbage Collection', 'Water Tank Cleaning',
      'Drainage/Sewage', 'Washroom Maintenance', 'Other',
    ],
  },
  SECURITY: {
    label: 'Security',
    subCategories: [
      'Gate Duty', 'Night Patrol', 'CCTV Monitoring', 'Visitor Verification',
      'Parking Duty', 'Fire Drill', 'Emergency Response', 'Access Control', 'Other',
    ],
  },
  ADMINISTRATION: {
    label: 'Administration',
    subCategories: [
      'Document Collection', 'NOC Processing', 'Meeting Arrangement',
      'Record Keeping', 'Vendor Coordination', 'Audit Preparation',
      'Communication/Notice', 'Compliance', 'Other',
    ],
  },
  FINANCE: {
    label: 'Finance',
    subCategories: [
      'Bill Collection', 'Payment Follow-up', 'Receipt Generation',
      'Expense Recording', 'Bank Deposit', 'Audit', 'Budget Planning', 'Other',
    ],
  },
  COMMON_AREA: {
    label: 'Common Area',
    subCategories: [
      'Gym Equipment', 'Swimming Pool', 'Club House', 'Children Play Area',
      'Community Hall', 'Parking Area', 'Garden/Park', 'Sports Facility', 'Other',
    ],
  },
  OTHER: {
    label: 'Other',
    subCategories: ['General', 'Other'],
  },
};

function isAdmin(role) {
  return ADMIN_ROLES.includes(String(role || '').toUpperCase());
}

// GET /api/tasks/categories
async function getCategories(_req, res) {
  return sendSuccess(res, TASK_CATEGORIES, 'Task categories');
}

// POST /api/tasks
async function createTask(req, res) {
  try {
    const { societyId, id: createdById, role } = req.user;
    if (!isAdmin(role)) return sendError(res, 'Insufficient permissions', 403);

    const { title, description, category, subCategory, priority, startDate, endDate, assigneeIds } = req.body;

    if (!title || String(title).trim().length < 3) return sendError(res, 'Title is required (min 3 chars)', 400);
    if (!category || !TASK_CATEGORIES[category]) return sendError(res, 'Invalid category', 400);
    if (!startDate || !endDate) return sendError(res, 'Start date and end date are required', 400);

    const start = new Date(startDate);
    const end = new Date(endDate);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) return sendError(res, 'Invalid dates', 400);
    if (end < start) return sendError(res, 'End date must be on or after start date', 400);

    const assignees = Array.isArray(assigneeIds)
      ? [...new Set(assigneeIds.map(String).filter(Boolean))]
      : [];

    if (assignees.length === 0) return sendError(res, 'At least one assignee is required', 400);

    // Validate assignees belong to the same society
    const validUsers = await prisma.user.findMany({
      where: { id: { in: assignees }, societyId, deletedAt: null, isActive: true },
      select: { id: true },
    });
    const validIds = validUsers.map((u) => u.id);
    if (validIds.length === 0) return sendError(res, 'No valid assignees found', 400);

    // Handle file uploads
    const attachmentData = (req.files || []).map((f) => ({
      fileName: f.originalname,
      fileType: f.mimetype,
      fileSize: f.size,
      fileUrl: `/uploads/tasks/${f.filename}`,
    }));

    const task = await prisma.task.create({
      data: {
        societyId,
        createdById,
        title: String(title).trim(),
        description: description ? String(description).trim() : null,
        category,
        subCategory: subCategory || null,
        priority: priority || 'MEDIUM',
        startDate: start,
        endDate: end,
        assignees: { create: validIds.map((userId) => ({ userId })) },
        attachments: attachmentData.length ? { create: attachmentData } : undefined,
      },
      include: {
        creator: { select: { id: true, name: true } },
        assignees: { include: { user: { select: { id: true, name: true, role: true } } } },
        attachments: true,
        _count: { select: { comments: true } },
      },
    });

    // Notify assignees (best-effort)
    setImmediate(() => {
      for (const uid of validIds) {
        if (uid === createdById) continue;
        notificationsService
          .sendNotification(createdById, societyId, {
            targetType: 'user',
            targetId: uid,
            title: 'New task assigned',
            body: task.title,
            type: 'MANUAL',
            route: `/tasks`,
          })
          .catch(() => {});
      }
    });

    return sendSuccess(res, task, 'Task created', 201);
  } catch (err) {
    console.error('createTask error:', err);
    return sendError(res, err.message, err.status || 500);
  }
}

// GET /api/tasks
async function listTasks(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { status, category, priority, assignedToMe } = req.query;

    const where = { societyId };
    if (status) where.status = String(status).toUpperCase();
    if (category) where.category = String(category).toUpperCase();
    if (priority) where.priority = String(priority).toUpperCase();

    // Non-admin users only see tasks they created or are assigned to
    if (!isAdmin(role) || assignedToMe === 'true') {
      where.OR = [
        { createdById: userId },
        { assignees: { some: { userId } } },
      ];
    }

    const tasks = await prisma.task.findMany({
      where,
      include: {
        creator: { select: { id: true, name: true } },
        assignees: { include: { user: { select: { id: true, name: true, role: true, phone: true } } } },
        attachments: true,
        _count: { select: { comments: true } },
      },
      orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
      take: 500,
    });

    return sendSuccess(res, tasks, 'Tasks retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// GET /api/tasks/:id
async function getTaskById(req, res) {
  try {
    const { societyId } = req.user;
    const task = await prisma.task.findUnique({
      where: { id: req.params.id },
      include: {
        creator: { select: { id: true, name: true, role: true } },
        assignees: { include: { user: { select: { id: true, name: true, role: true, phone: true } } } },
        attachments: true,
        comments: {
          include: { user: { select: { id: true, name: true } } },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    if (!task || task.societyId !== societyId) return sendError(res, 'Task not found', 404);

    return sendSuccess(res, task, 'Task retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// PUT /api/tasks/:id
async function updateTask(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const existing = await prisma.task.findUnique({
      where: { id },
      include: { assignees: true },
    });
    if (!existing || existing.societyId !== societyId) return sendError(res, 'Task not found', 404);

    const isCreator = existing.createdById === userId;
    const isAssignee = existing.assignees.some((a) => a.userId === userId);
    if (!isCreator && !isAdmin(role) && !isAssignee) return sendError(res, 'Insufficient permissions', 403);

    const { title, description, category, subCategory, priority, status, startDate, endDate, assigneeIds, statusNote } = req.body;

    const updateData = {};

    if (title !== undefined) updateData.title = String(title).trim();
    if (description !== undefined) updateData.description = description ? String(description).trim() : null;
    if (category && TASK_CATEGORIES[category]) updateData.category = category;
    if (subCategory !== undefined) updateData.subCategory = subCategory || null;
    if (priority) updateData.priority = priority;
    if (statusNote !== undefined) updateData.statusNote = statusNote || null;

    if (status) {
      updateData.status = status;
      if (status === 'COMPLETED') updateData.completedAt = new Date();
    }

    if (startDate) {
      const s = new Date(startDate);
      if (!isNaN(s.getTime())) updateData.startDate = s;
    }
    if (endDate) {
      const e = new Date(endDate);
      if (!isNaN(e.getTime())) updateData.endDate = e;
    }

    // Handle new attachments
    if (req.files && req.files.length > 0) {
      const attachmentData = req.files.map((f) => ({
        fileName: f.originalname,
        fileType: f.mimetype,
        fileSize: f.size,
        fileUrl: `/uploads/tasks/${f.filename}`,
      }));
      updateData.attachments = { create: attachmentData };
    }

    // Update assignees if provided (only by creator/admin)
    if (Array.isArray(assigneeIds) && (isCreator || isAdmin(role))) {
      const newIds = [...new Set(assigneeIds.map(String).filter(Boolean))];
      const validUsers = await prisma.user.findMany({
        where: { id: { in: newIds }, societyId, deletedAt: null, isActive: true },
        select: { id: true },
      });
      const validIds = validUsers.map((u) => u.id);

      if (validIds.length > 0) {
        // Remove old and create new
        await prisma.taskAssignee.deleteMany({ where: { taskId: id } });
        updateData.assignees = { create: validIds.map((userId) => ({ userId })) };
      }
    }

    const updated = await prisma.task.update({
      where: { id },
      data: updateData,
      include: {
        creator: { select: { id: true, name: true } },
        assignees: { include: { user: { select: { id: true, name: true, role: true } } } },
        attachments: true,
        _count: { select: { comments: true } },
      },
    });

    return sendSuccess(res, updated, 'Task updated');
  } catch (err) {
    console.error('updateTask error:', err);
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/tasks/:id/status
async function updateTaskStatus(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;
    const { status, statusNote } = req.body;

    if (!status) return sendError(res, 'status is required', 400);

    const existing = await prisma.task.findUnique({
      where: { id },
      include: { assignees: true },
    });
    if (!existing || existing.societyId !== societyId) return sendError(res, 'Task not found', 404);

    const isCreator = existing.createdById === userId;
    const isAssignee = existing.assignees.some((a) => a.userId === userId);
    if (!isCreator && !isAdmin(role) && !isAssignee) return sendError(res, 'Insufficient permissions', 403);

    const data = { status: String(status).toUpperCase(), statusNote: statusNote || null };
    if (data.status === 'COMPLETED') data.completedAt = new Date();

    const updated = await prisma.task.update({
      where: { id },
      data,
      include: {
        creator: { select: { id: true, name: true } },
        assignees: { include: { user: { select: { id: true, name: true, role: true } } } },
        attachments: true,
        _count: { select: { comments: true } },
      },
    });

    return sendSuccess(res, updated, 'Task status updated');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// POST /api/tasks/:id/comments
async function addComment(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;
    const { body } = req.body;

    if (!body || String(body).trim().length === 0) return sendError(res, 'Comment body is required', 400);

    const task = await prisma.task.findUnique({ where: { id } });
    if (!task || task.societyId !== societyId) return sendError(res, 'Task not found', 404);

    const comment = await prisma.taskComment.create({
      data: { taskId: id, userId, body: String(body).trim() },
      include: { user: { select: { id: true, name: true } } },
    });

    return sendSuccess(res, comment, 'Comment added', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// DELETE /api/tasks/:id
async function deleteTask(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const task = await prisma.task.findUnique({ where: { id } });
    if (!task || task.societyId !== societyId) return sendError(res, 'Task not found', 404);
    if (task.createdById !== userId && !isAdmin(role)) return sendError(res, 'Insufficient permissions', 403);

    await prisma.task.delete({ where: { id } });
    return sendSuccess(res, null, 'Task deleted');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

// DELETE /api/tasks/:taskId/attachments/:attachmentId
async function deleteAttachment(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { taskId, attachmentId } = req.params;

    const task = await prisma.task.findUnique({ where: { id: taskId } });
    if (!task || task.societyId !== societyId) return sendError(res, 'Task not found', 404);
    if (task.createdById !== userId && !isAdmin(role)) return sendError(res, 'Insufficient permissions', 403);

    await prisma.taskAttachment.delete({ where: { id: attachmentId } });
    return sendSuccess(res, null, 'Attachment deleted');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = {
  getCategories,
  createTask,
  listTasks,
  getTaskById,
  updateTask,
  updateTaskStatus,
  addComment,
  deleteTask,
  deleteAttachment,
};
