const chatService = require('./chat.service');

// GET /api/chat/rooms
async function listRooms(req, res, next) {
  try {
    const rooms = await chatService.getRoomsForUser(req.user.societyId, req.user.id);
    res.json({ success: true, rooms });
  } catch (err) {
    next(err);
  }
}

// GET /api/chat/group
async function getGroupRoom(req, res, next) {
  try {
    const room = await chatService.getOrCreateGroupRoom(req.user.societyId);
    res.json({ success: true, room });
  } catch (err) {
    next(err);
  }
}

// POST /api/chat/dm/:userId
async function getOrCreateDM(req, res, next) {
  try {
    const room = await chatService.getOrCreateDMRoom(
      req.user.societyId,
      req.user.id,
      req.params.userId
    );
    res.json({ success: true, room });
  } catch (err) {
    next(err);
  }
}

// GET /api/chat/rooms/:roomId/messages
async function getMessages(req, res, next) {
  try {
    const room = await chatService.getRoomForUser(req.params.roomId, req.user.id);
    if (!room) return res.status(403).json({ success: false, message: 'Access denied' });

    const { before, limit } = req.query;
    const messages = await chatService.getMessages(req.params.roomId, {
      before,
      limit: limit ? parseInt(limit) : 30,
    });
    res.json({ success: true, messages });
  } catch (err) {
    next(err);
  }
}

// POST /api/chat/rooms/:roomId/messages
async function sendMessage(req, res, next) {
  try {
    const room = await chatService.getRoomForUser(req.params.roomId, req.user.id);
    if (!room) return res.status(403).json({ success: false, message: 'Access denied' });

    const { type, body, duration } = req.body;
    const files = req.files || [];

    const message = await chatService.sendMessage(req.params.roomId, req.user.id, {
      type: type || 'TEXT',
      body,
      duration,
      files,
    });

    // Push notification (fire and forget) — sender name comes from the message itself
    const senderName = message.sender?.name ?? 'Someone';
    chatService.notifyNewMessage(room, message, senderName).catch(() => {});

    // Emit via Socket.IO if available
    const io = req.app.get('io');
    if (io) io.to(req.params.roomId).emit('new_message', message);

    res.status(201).json({ success: true, message });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/chat/messages/:messageId
async function deleteMessage(req, res, next) {
  try {
    const result = await chatService.deleteMessage(req.params.messageId, req.user.id);
    if (!result) return res.status(403).json({ success: false, message: 'Not allowed' });

    const io = req.app.get('io');
    if (io) io.to(result.roomId).emit('message_deleted', { messageId: req.params.messageId });

    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

// POST /api/chat/rooms/:roomId/read
async function markRead(req, res, next) {
  try {
    await chatService.markRead(req.params.roomId, req.user.id);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

// POST /api/chat/rooms/:roomId/mute   body: { mute: true|false }
async function setMute(req, res, next) {
  try {
    const room = await chatService.getRoomForUser(req.params.roomId, req.user.id);
    if (!room) return res.status(403).json({ success: false, message: 'Access denied' });
    const mute = req.body.mute === true || req.body.mute === 'true';
    await chatService.setMute(req.params.roomId, req.user.id, mute);
    res.json({ success: true, isMuted: mute });
  } catch (err) {
    next(err);
  }
}

// GET /api/chat/rooms/:roomId/mute
async function getMuteStatus(req, res, next) {
  try {
    const room = await chatService.getRoomForUser(req.params.roomId, req.user.id);
    if (!room) return res.status(403).json({ success: false, message: 'Access denied' });
    const isMuted = await chatService.getMuteStatus(req.params.roomId, req.user.id);
    res.json({ success: true, isMuted });
  } catch (err) {
    next(err);
  }
}

module.exports = { listRooms, getGroupRoom, getOrCreateDM, getMessages, sendMessage, deleteMessage, markRead, setMute, getMuteStatus };
