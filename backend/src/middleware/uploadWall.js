const multer = require('multer');
const path = require('path');
const fs = require('fs');

const ALLOWED = {
  '.jpg':  ['image/jpeg'],
  '.jpeg': ['image/jpeg'],
  '.png':  ['image/png'],
  '.gif':  ['image/gif'],
  '.webp': ['image/webp'],
  '.mp4':  ['video/mp4'],
  '.mov':  ['video/quicktime'],
  '.avi':  ['video/x-msvideo'],
  '.mkv':  ['video/x-matroska'],
};

function sanitizeFilename(original) {
  const ext  = path.extname(original).toLowerCase();
  const base = path.basename(original, ext).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 60);
  return base + ext;
}

const uploadDir = path.join(__dirname, '../../uploads/wall');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const safe = sanitizeFilename(file.originalname);
    cb(null, 'wall-' + Date.now() + '-' + safe);
  },
});

const fileFilter = (_req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedMimes = ALLOWED[ext];
  if (allowedMimes && allowedMimes.includes(file.mimetype)) return cb(null, true);
  cb(new Error('Only images (jpeg/jpg/png/gif/webp) and videos (mp4/mov/avi/mkv) are allowed'));
};

module.exports = multer({ storage, fileFilter, limits: { fileSize: 50 * 1024 * 1024 } });
