const prisma = require('../../config/db');
const { sendSuccess, sendError } = require('../../utils/response');
const notificationsService = require('../notifications/notifications.service');

function isSocietyAdminRole(role) {
  const r = String(role || '').toUpperCase();
  return r === 'PRAMUKH' || r === 'CHAIRMAN' || r === 'SECRETARY';
}

async function createPoll(req, res) {
  try {
    const { societyId, id: createdById, role } = req.user;
    if (!isSocietyAdminRole(role)) return sendError(res, 'Insufficient permissions', 403);

    const { title, description, options, recipientIds, recipientRoles, closesAt } = req.body || {};
    if (!title || String(title).trim().length < 3) {
      return sendError(res, 'title is required (min 3 chars)', 400);
    }
    if (!Array.isArray(options) || options.length < 2) {
      return sendError(res, 'options must be an array with at least 2 items', 400);
    }
    const cleanedOptions = options
      .map((t) => String(t ?? '').trim())
      .filter((t) => t.length > 0)
      .slice(0, 10);
    if (cleanedOptions.length < 2) {
      return sendError(res, 'Provide at least 2 non-empty options', 400);
    }

    const roles =
      Array.isArray(recipientRoles) && recipientRoles.length
        ? [...new Set(recipientRoles.map((x) => String(x ?? '').trim()).filter(Boolean).map((x) => x.toUpperCase()))]
        : [];

    const recipients = Array.isArray(recipientIds)
      ? [...new Set(recipientIds.map((x) => String(x)).filter(Boolean))]
      : [];

    if (roles.length === 0 && recipients.length === 0) {
      return sendError(res, 'Select at least 1 receiver (recipientIds or recipientRoles)', 400);
    }

    const closeDate = closesAt ? new Date(closesAt) : null;
    if (closeDate && Number.isNaN(closeDate.getTime())) {
      return sendError(res, 'Invalid closesAt', 400);
    }

    // Resolve recipients either by explicit IDs (custom) or by role/category.
    // Role match is case-insensitive; special role "ALL" targets all active users in the society.
    const wantsAll = roles.includes('ALL');
    const validUsers = await prisma.user.findMany({
      where: {
        societyId,
        deletedAt: null,
        isActive: true,
        ...(roles.length
          ? wantsAll
            ? {}
            : { role: { in: roles } }
          : { id: { in: recipients } }),
      },
      select: { id: true },
    });
    const validIds = validUsers.map((u) => u.id);
    if (validIds.length === 0) {
      return sendError(res, 'No valid recipients found in this society', 400);
    }

    const poll = await prisma.poll.create({
      data: {
        societyId,
        createdById,
        title: String(title).trim(),
        description: description ? String(description).trim() : null,
        closesAt: closeDate,
        options: {
          create: cleanedOptions.map((text, idx) => ({
            text,
            sortOrder: idx,
          })),
        },
        recipients: {
          create: validIds.map((userId) => ({ userId })),
        },
      },
      include: {
        creator: { select: { id: true, name: true } },
        options: { orderBy: { sortOrder: 'asc' } },
        recipients: { select: { userId: true } },
      },
    });

    // Notify recipients (best-effort, async)
    setImmediate(() => {
      for (const uid of validIds) {
        notificationsService
          .sendNotification(createdById, societyId, {
            targetType: 'user',
            targetId: uid,
            title: 'New poll',
            body: poll.title,
            type: 'MANUAL',
            route: `/polls/${poll.id}`,
          })
          .catch(() => {});
      }
    });

    return sendSuccess(res, poll, 'Poll created', 201);
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function listInboxPolls(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { status } = req.query;
    const where = {
      societyId,
      recipients: { some: { userId } },
    };
    if (status) where.status = String(status).toUpperCase();

    const polls = await prisma.poll.findMany({
      where,
      include: {
        creator: { select: { id: true, name: true } },
        options: { orderBy: { sortOrder: 'asc' } },
        votes: {
          where: { userId },
          select: { id: true, optionId: true, createdAt: true },
        },
        _count: { select: { recipients: true, votes: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    const pollIds = polls.map((p) => p.id);
    const voteGroups =
      pollIds.length > 0
        ? await prisma.pollVote.groupBy({
            by: ['pollId', 'optionId'],
            where: { pollId: { in: pollIds } },
            _count: { _all: true },
          })
        : [];

    const countsByPoll = {};
    for (const g of voteGroups) {
      const pid = g.pollId;
      if (!countsByPoll[pid]) countsByPoll[pid] = {};
      countsByPoll[pid][g.optionId] = g._count?._all ?? 0;
    }

    const data = polls.map((p) => {
      const optionCounts = countsByPoll[p.id] || {};
      return {
        ...p,
        myVote: p.votes?.[0] || null,
        votes: undefined,
        resultsPreview: (p.options || []).map((o) => ({
          id: o.id,
          text: o.text,
          votes: optionCounts[o.id] || 0,
        })),
        totalVotes: p._count?.votes ?? 0,
        totalRecipients: p._count?.recipients ?? 0,
      };
    });

    return sendSuccess(res, data, 'Inbox polls retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function listMyCreatedPolls(req, res) {
  try {
    const { societyId, id: createdById } = req.user;
    const polls = await prisma.poll.findMany({
      where: { societyId, createdById },
      include: {
        options: { orderBy: { sortOrder: 'asc' } },
        _count: { select: { recipients: true, votes: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    const pollIds = polls.map((p) => p.id);
    const voteGroups =
      pollIds.length > 0
        ? await prisma.pollVote.groupBy({
            by: ['pollId', 'optionId'],
            where: { pollId: { in: pollIds } },
            _count: { _all: true },
          })
        : [];

    const countsByPoll = {};
    for (const g of voteGroups) {
      const pid = g.pollId;
      if (!countsByPoll[pid]) countsByPoll[pid] = {};
      countsByPoll[pid][g.optionId] = g._count?._all ?? 0;
    }

    const data = polls.map((p) => {
      const optionCounts = countsByPoll[p.id] || {};
      return {
        ...p,
        resultsPreview: (p.options || []).map((o) => ({
          id: o.id,
          text: o.text,
          votes: optionCounts[o.id] || 0,
        })),
        totalVotes: p._count?.votes ?? 0,
        totalRecipients: p._count?.recipients ?? 0,
      };
    });

    return sendSuccess(res, data, 'Created polls retrieved');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function getPollById(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;

    const poll = await prisma.poll.findUnique({
      where: { id },
      include: {
        creator: { select: { id: true, name: true } },
        options: { orderBy: { sortOrder: 'asc' } },
        recipients: { select: { userId: true } },
        votes: { where: { userId }, select: { id: true, optionId: true, createdAt: true } },
      },
    });
    if (!poll || poll.societyId !== societyId) return sendError(res, 'Poll not found', 404);

    const isRecipient = poll.recipients.some((r) => r.userId === userId);
    const isCreator = poll.createdById === userId;
    if (!isRecipient && !isCreator) return sendError(res, 'Forbidden', 403);

    return sendSuccess(
      res,
      {
        ...poll,
        myVote: poll.votes?.[0] || null,
        votes: undefined,
      },
      'Poll retrieved'
    );
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function voteOnPoll(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;
    const { optionId } = req.body || {};
    if (!optionId) return sendError(res, 'optionId is required', 400);

    const poll = await prisma.poll.findUnique({
      where: { id },
      include: {
        recipients: { select: { userId: true } },
        options: { select: { id: true } },
      },
    });
    if (!poll || poll.societyId !== societyId) return sendError(res, 'Poll not found', 404);

    if (poll.status !== 'OPEN') return sendError(res, 'Poll is closed', 400);
    if (poll.closesAt && new Date(poll.closesAt).getTime() < Date.now()) {
      return sendError(res, 'Poll has expired', 400);
    }
    const isRecipient = poll.recipients.some((r) => r.userId === userId);
    if (!isRecipient) return sendError(res, 'You are not a recipient of this poll', 403);

    const isValidOption = poll.options.some((o) => o.id === String(optionId));
    if (!isValidOption) return sendError(res, 'Invalid optionId', 400);

    // Single-choice: unique(pollId,userId) prevents double-vote.
    const vote = await prisma.pollVote.create({
      data: {
        pollId: poll.id,
        optionId: String(optionId),
        userId,
      },
    });

    return sendSuccess(res, vote, 'Vote submitted', 201);
  } catch (err) {
    // Prisma unique constraint violation
    if (String(err.code) === 'P2002') {
      return sendError(res, 'You have already voted on this poll', 400);
    }
    return sendError(res, err.message, err.status || 500);
  }
}

async function getPollResults(req, res) {
  try {
    const { societyId, id: userId, role } = req.user;
    const { id } = req.params;

    const poll = await prisma.poll.findUnique({
      where: { id },
      include: {
        creator: { select: { id: true, name: true } },
        options: { orderBy: { sortOrder: 'asc' } },
        recipients: { include: { user: { select: { id: true, name: true, role: true, phone: true } } } },
        votes: {
          include: {
            option: { select: { id: true, text: true } },
            user: { select: { id: true, name: true, role: true, phone: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!poll || poll.societyId !== societyId) return sendError(res, 'Poll not found', 404);
    const canViewResults = poll.createdById === userId || isSocietyAdminRole(role);
    if (!canViewResults) return sendError(res, 'Only creator can view results', 403);

    const counts = {};
    for (const opt of poll.options) counts[opt.id] = 0;
    for (const v of poll.votes) counts[v.optionId] = (counts[v.optionId] || 0) + 1;

    return sendSuccess(
      res,
      {
        poll: {
          id: poll.id,
          title: poll.title,
          description: poll.description,
          status: poll.status,
          closesAt: poll.closesAt,
          createdAt: poll.createdAt,
          creator: poll.creator,
        },
        options: poll.options.map((o) => ({
          id: o.id,
          text: o.text,
          votes: counts[o.id] || 0,
        })),
        recipients: poll.recipients.map((r) => r.user),
        votes: poll.votes.map((v) => ({
          id: v.id,
          createdAt: v.createdAt,
          option: v.option,
          user: v.user,
        })),
        totalVotes: poll.votes.length,
        totalRecipients: poll.recipients.length,
      },
      'Poll results retrieved'
    );
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

async function closePoll(req, res) {
  try {
    const { societyId, id: userId } = req.user;
    const { id } = req.params;
    const poll = await prisma.poll.findUnique({ where: { id } });
    if (!poll || poll.societyId !== societyId) return sendError(res, 'Poll not found', 404);
    if (poll.createdById !== userId) return sendError(res, 'Only creator can close poll', 403);

    const updated = await prisma.poll.update({
      where: { id },
      data: { status: 'CLOSED' },
    });
    return sendSuccess(res, updated, 'Poll closed');
  } catch (err) {
    return sendError(res, err.message, err.status || 500);
  }
}

module.exports = {
  createPoll,
  listInboxPolls,
  listMyCreatedPolls,
  getPollById,
  voteOnPoll,
  getPollResults,
  closePoll,
};

