const express = require('express');
const router = express.Router();

const auth = require('../../middleware/auth');
const roleGuard = require('../../middleware/roleGuard');
const createUploader = require('../../middleware/uploadTask');
const c = require('./tasks.controller');

const upload = createUploader();

router.use(auth);

// Categories (public to all authenticated users)
router.get('/categories', c.getCategories);

// CRUD
router.get('/', c.listTasks);
router.get('/:id', c.getTaskById);

router.post('/',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER']),
  upload.array('attachments', 10),
  c.createTask,
);

router.put('/:id',
  upload.array('attachments', 10),
  c.updateTask,
);

router.post('/:id/status', c.updateTaskStatus);
router.post('/:id/comments', c.addComment);

router.delete('/:id',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER']),
  c.deleteTask,
);

router.delete('/:taskId/attachments/:attachmentId',
  roleGuard(['PRAMUKH', 'CHAIRMAN', 'SECRETARY', 'MANAGER']),
  c.deleteAttachment,
);

module.exports = router;
