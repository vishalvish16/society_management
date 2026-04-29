const { Router } = require('express');
const { sendSuccess } = require('../../utils/response');
const { getAppInfo } = require('../../utils/platformSettings');

const router = Router();

// Public — no auth required
router.get('/', async (req, res, next) => {
  try {
    const info = await getAppInfo();
    return sendSuccess(res, info, 'App info retrieved');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
