const multer = require('multer');
const path = require('path');
const fs = require('fs');

function createUploader() {
  const uploadDir = path.join(__dirname, '../../uploads/tasks');
  if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
      const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
      cb(null, 'task-' + unique + path.extname(file.originalname));
    },
  });

  const fileFilter = (_req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|webp|pdf|doc|docx|xls|xlsx|txt|mp4|mov|mkv|avi|3gp/;
    const ok = allowed.test(file.mimetype) || allowed.test(path.extname(file.originalname).toLowerCase());
    ok ? cb(null, true) : cb(new Error('Unsupported file type'));
  };

  return multer({ storage, fileFilter, limits: { fileSize: 25 * 1024 * 1024 } }); // 25 MB
}

module.exports = createUploader;
