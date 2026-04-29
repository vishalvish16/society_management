const multer = require('multer');
const path = require('path');
const fs = require('fs');

const ALLOWED = {
  '.jpg':  ['image/jpeg'],
  '.jpeg': ['image/jpeg'],
  '.png':  ['image/png'],
  '.webp': ['image/webp'],
  '.pdf':  ['application/pdf'],
};

function sanitizeFilename(original) {
  const ext  = path.extname(original).toLowerCase();
  const base = path.basename(original, ext).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 60);
  return base + ext;
}

const uploadDir = path.join(__dirname, '../../uploads/assets');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const safe = sanitizeFilename(file.originalname);
    cb(null, 'asset-' + Date.now() + '-' + safe);
  },
});

const fileFilter = (_req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedMimes = ALLOWED[ext];
  if (allowedMimes && allowedMimes.includes(file.mimetype)) return cb(null, true);
  cb(new Error('Only images (jpg, png, webp) and PDFs are allowed'));
};

module.exports = multer({ storage, fileFilter, limits: { fileSize: 10 * 1024 * 1024 } });
