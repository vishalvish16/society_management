const prisma = require('../../config/db');
const { pushToUsers } = require('../../utils/push');

// ── helpers ────────────────────────────────────────────────────────────────

function dmKey(a, b) {
  return [a, b].sort().join(',');
}

// ── rooms ──────────────────────────────────────────────────────────────────

async function getOrCreateGroupRoom(societyId) {
  let room = await prisma.chatRoom.findFirst({
    where: { societyId, type: 'GROUP' },
  });
  if (!room) {
    room = await prisma.chatRoom.create({
      data: { societyId, type: 'GROUP', name: 'Society Chat' },
    });
  }
  return room;
}

async function getOrCreateDMRoom(societyId, userAId, userBId) {
  const key = dmKey(userAId, userBId);
  let room = await prisma.chatRoom.findUnique({ where: { dmKey: key } });
  if (!room) {
    room = await prisma.chatRoom.create({
      data: {
        societyId,
        type: 'DIRECT',
        dmKey: key,
        members: {
          create: [{ userId: userAId }, { userId: userBId }],
        },
      },
    });
  }
  return room;
}

async function getRoomForUser(roomId, userId) {
  const room = await prisma.chatRoom.findUnique({ where: { id: roomId } });
  if (!room) return null;

  if (room.type === 'GROUP') {
    // Any member of the society can access group chat
    const user = await prisma.user.findFirst({
      where: { id: userId, societyId: room.societyId, isActive: true, deletedAt: null },
    });
    return user ? room : null;
  }

  // For DIRECT: must be a member of the room
  const membership = await prisma.chatRoomMember.findUnique({
    where: { roomId_userId: { roomId, userId } },
  });
  return membership ? room : null;
}

// ── messages ──────────────────────────────────────────────────────────────

async function getMessages(roomId, { before, limit = 30 }) {
  const where = { roomId, deletedAt: null };
  if (before) where.createdAt = { lt: new Date(before) };

  const messages = await prisma.chatMessage.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit,
    include: {
      sender: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
      attachments: true,
    },
  });
  return messages.reverse();
}

async function sendMessage(roomId, senderId, { type = 'TEXT', body, duration, files }) {
  const attachments = (files || []).map((f) => ({
    url: `/uploads/chat/${f.filename}`,
    filename: f.originalname,
    mimeType: f.mimetype,
    size: f.size,
  }));

  const message = await prisma.chatMessage.create({
    data: {
      roomId,
      senderId,
      type,
      body: body || null,
      duration: duration ? parseInt(duration) : null,
      attachments: attachments.length ? { create: attachments } : undefined,
    },
    include: {
      sender: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
      attachments: true,
    },
  });

  // Update room updatedAt so it floats to top
  await prisma.chatRoom.update({ where: { id: roomId }, data: { updatedAt: new Date() } });

  return message;
}

async function deleteMessage(messageId, userId) {
  const msg = await prisma.chatMessage.findUnique({ where: { id: messageId } });
  if (!msg || msg.senderId !== userId) return null;
  return prisma.chatMessage.update({
    where: { id: messageId },
    data: { deletedAt: new Date() },
  });
}

// ── mark read ──────────────────────────────────────────────────────────────

async function markRead(roomId, userId) {
  await prisma.chatRoomMember.upsert({
    where: { roomId_userId: { roomId, userId } },
    create: { roomId, userId, lastReadAt: new Date() },
    update: { lastReadAt: new Date() },
  });
}

// ── room list (with unread counts) ────────────────────────────────────────

async function getRoomsForUser(societyId, userId) {
  // GROUP rooms for this society
  const groupRooms = await prisma.chatRoom.findMany({
    where: { societyId, type: 'GROUP' },
    include: {
      messages: {
        where: { deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 1,
        include: {
          sender: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
          attachments: true,
        },
      },
      members: { where: { userId } },
    },
  });

  // DIRECT rooms for this user in this society
  const directRooms = await prisma.chatRoom.findMany({
    where: {
      societyId,
      type: 'DIRECT',
      members: { some: { userId } },
    },
    include: {
      messages: {
        where: { deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 1,
        include: {
          sender: { select: { id: true, name: true, profilePhotoUrl: true, role: true } },
          attachments: true,
        },
      },
      members: {
        include: { user: { select: { id: true, name: true, profilePhotoUrl: true, role: true } } },
      },
    },
  });

  const format = async (room) => {
    const memberRec = room.members.find((m) => m.userId === userId);
    const lastReadAt = memberRec?.lastReadAt ?? null;

    const unread = await prisma.chatMessage.count({
      where: {
        roomId: room.id,
        deletedAt: null,
        senderId: { not: userId },
        ...(lastReadAt ? { createdAt: { gt: lastReadAt } } : {}),
      },
    });

    const lastMsg = room.messages[0] ?? null;
    return {
      id: room.id,
      type: room.type,
      name: room.name,
      updatedAt: room.updatedAt,
      isMuted: memberRec?.isMuted ?? false,
      lastMessage: lastMsg
        ? { ...lastMsg, roomId: room.id, senderId: lastMsg.senderId ?? lastMsg.sender?.id ?? '' }
        : null,
      unreadCount: unread,
    };
  };

  const formatted = await Promise.all([...groupRooms, ...directRooms].map(format));

  // For direct rooms — attach the other participant info
  for (const room of formatted) {
    const raw = directRooms.find((r) => r.id === room.id);
    if (raw) {
      const other = raw.members.find((m) => m.userId !== userId);
      room.otherUser = other?.user ?? null;
    }
  }

  return formatted.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
}

// ── mute / unmute ─────────────────────────────────────────────────────────

async function setMute(roomId, userId, mute) {
  await prisma.chatRoomMember.upsert({
    where: { roomId_userId: { roomId, userId } },
    create: { roomId, userId, isMuted: mute },
    update: { isMuted: mute },
  });
}

async function getMuteStatus(roomId, userId) {
  const member = await prisma.chatRoomMember.findUnique({
    where: { roomId_userId: { roomId, userId } },
    select: { isMuted: true },
  });
  return member?.isMuted ?? false;
}

// ── push notification for new message ────────────────────────────────────

async function notifyNewMessage(room, message, senderName) {
  const body =
    message.type === 'TEXT'
      ? message.body
      : message.type === 'VOICE'
      ? '🎤 Voice message'
      : message.type === 'IMAGE'
      ? '📷 Photo'
      : '📎 Document';

  if (room.type === 'GROUP') {
    // Push to all active society members except sender — skip muted members
    const members = await prisma.chatRoomMember.findMany({
      where: { roomId: room.id, isMuted: false, userId: { not: message.senderId } },
      select: { userId: true },
    });
    // Also include society members who have no membership record yet (never joined explicitly)
    // They are not in chat_room_members, so check active users minus muted ones
    const mutedUserIds = await prisma.chatRoomMember.findMany({
      where: { roomId: room.id, isMuted: true },
      select: { userId: true },
    });
    const mutedSet = new Set(mutedUserIds.map((m) => m.userId));

    const allUsers = await prisma.user.findMany({
      where: {
        societyId: room.societyId,
        isActive: true,
        deletedAt: null,
        fcmToken: { not: null },
        id: { not: message.senderId },
      },
      select: { id: true },
    });
    const targets = allUsers.filter((u) => !mutedSet.has(u.id)).map((u) => u.id);

    if (targets.length) {
      await pushToUsers(targets, {
        title: `${senderName} in ${room.name || 'Society Chat'}`,
        body,
        data: { route: `/chat/room/${room.id}`, roomId: room.id, type: 'CHAT' },
      });
    }
  } else {
    // DM: push to the other participant only if they haven't muted
    const other = await prisma.chatRoomMember.findFirst({
      where: { roomId: room.id, userId: { not: message.senderId }, isMuted: false },
    });
    if (other) {
      await pushToUsers([other.userId], {
        title: senderName,
        body,
        data: { route: `/chat/room/${room.id}`, roomId: room.id, type: 'CHAT' },
      });
    }
  }
}

module.exports = {
  getOrCreateGroupRoom,
  getOrCreateDMRoom,
  getRoomForUser,
  getMessages,
  sendMessage,
  deleteMessage,
  markRead,
  setMute,
  getMuteStatus,
  getRoomsForUser,
  notifyNewMessage,
};
