/**
 * Send a success response with standard envelope.
 * @param {import('express').Response} res
 * @param {any} data - Response payload
 * @param {string} message - Human-readable message
 * @param {number} [status=200] - HTTP status code
 */
function sendSuccess(res, data, message = 'Success', status = 200) {
  return res.status(status).json({
    success: true,
    data,
    message,
  });
}

/**
 * Send an error response with standard envelope.
 * @param {import('express').Response} res
 * @param {string} message - Human-readable error message
 * @param {number} [status=500] - HTTP status code
 */
function sendError(res, message = 'Internal Server Error', status = 500) {
  return res.status(status).json({
    success: false,
    data: null,
    message,
  });
}

module.exports = { sendSuccess, sendError };
