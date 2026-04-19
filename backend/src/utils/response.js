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
 * @param {object|null} [data=null] - Optional structured details (e.g. scan result codes)
 */
function sendError(res, message = 'Internal Server Error', status = 500, data = null) {
  return res.status(status).json({
    success: false,
    data,
    message,
  });
}

module.exports = { sendSuccess, sendError };
