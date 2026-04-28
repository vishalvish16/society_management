const express = require('express');
const router = express.Router();

const auth = require('../../middleware/auth');
const uploadWall = require('../../middleware/uploadWall');
const c = require('./wall.controller');

router.use(auth);

// Feed
router.get('/', c.listPosts);

// Posts
router.post('/', uploadWall.array('media', 10), c.createPost);
router.get('/:id', c.getPost);
router.patch('/:id/hide', c.toggleHidePost);
router.post('/:id/like', c.toggleLike);
router.delete('/:id', c.deletePost);

// Comments
router.get('/:id/comments', c.listComments);
router.post('/:id/comments', c.addComment);
router.patch('/:id/comments/:commentId/hide', c.toggleHideComment);
router.delete('/:id/comments/:commentId', c.deleteComment);

module.exports = router;
