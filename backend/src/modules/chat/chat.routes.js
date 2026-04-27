const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const ctrl = require('./chat.controller');
const createUploader = require('../../middleware/uploadChat');

const upload = createUploader();

router.use(authenticate);

router.get('/rooms',                          ctrl.listRooms);
router.get('/members',                        ctrl.listMembers);
router.get('/group',                          ctrl.getGroupRoom);
router.post('/dm/:userId',                    ctrl.getOrCreateDM);
router.get('/rooms/:roomId/messages',         ctrl.getMessages);
router.post('/rooms/:roomId/messages',        upload.array('files', 5), ctrl.sendMessage);
router.delete('/messages/:messageId',         ctrl.deleteMessage);
router.post('/rooms/:roomId/read',            ctrl.markRead);
router.get('/rooms/:roomId/mute',             ctrl.getMuteStatus);
router.post('/rooms/:roomId/mute',            ctrl.setMute);

module.exports = router;
