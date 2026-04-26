let _io = null;

/**
 * Store Socket.IO instance for access in schedulers/services.
 * This avoids circular imports from server bootstrap.
 */
function setIO(io) {
  _io = io;
}

function getIO() {
  return _io;
}

module.exports = { setIO, getIO };

