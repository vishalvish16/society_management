const multer = require('multer');
const path = require('path');
const fs = require('fs');

const ALLOWED = {
  '.jpg':  ['image/jpeg'],
  '.jpeg': ['image/jpeg'],
  '.png':  ['image/png'],
  '.gif':  ['image/gif'],
  '.webp': ['image/webp'],
  '.pdf':  ['application/pdf'],
  '.doc':  ['application/msword'],
  '.docx': ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  '.xls':  ['application/vnd.ms-excel'],
  '.xlsx': ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  '.txt':  ['text/plain'],
  '.mp3':  ['audio/mpeg'],
  '.m4a':  ['audio/mp4', 'audio/x-m4a'],
  '.ogg':  ['audio/ogg'],
  '.wav':  ['audio/wav'],
  '.aac':  ['audio/aac'],
  '.webm': ['video/webm', 'audio/webm'],
  '.mp4':  ['video/mp4'],
  '.mov':  ['video/quicktime'],
  '.mkv':  ['video/x-matroska'],
  '.avi':  ['video/x-msvideo'],
  '.3gp':  ['video/3gpp'],
};

function sanitizeFilename(original) {
  const ext  = path.extname(original).toLowerCase();
  const base = path.basename(original, ext).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 60);
  return base + ext;
}

function createUploader() {
  const uploadDir = path.join(__dirname, '../../uploads/chat');
  if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
      const safe = sanitizeFilename(file.originalname);
      cb(null, 'chat-' + Date.now() + '-' + safe);
    },
  });

  const fileFilter = (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedMimes = ALLOWED[ext];
    if (allowedMimes && allowedMimes.includes(file.mimetype)) return cb(null, true);
    cb(new Error('Unsupported file type'));
  };

  return multer({ storage, fileFilter, limits: { fileSize: 100 * 1024 * 1024 } });
}

module.exports = createUploader;
