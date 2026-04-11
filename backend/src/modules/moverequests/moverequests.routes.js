const express = require('express');
const router = express.Router();
const moveRequestsController = require('./moverequests.controller');
const { authenticateUser } = require('../../middlewares/auth.middleware');

router.get('/', authenticateUser, moveRequestsController.getAllMoveRequests);
router.post('/', authenticateUser, moveRequestsController.createMoveRequest);
router.put('/:id', authenticateUser, moveRequestsController.updateMoveRequest);
router.delete('/:id', authenticateUser, moveRequestsController.deleteMoveRequest);

module.exports = router;
