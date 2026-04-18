const multer = require('multer');
const path = require('path');
const fs = require('fs');

const createUploader = (subFolder) => {
  const uploadDir = path.join(__dirname, '../../uploads', subFolder);
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }

  const storage = multer.diskStorage({
    destination: function (req, file, cb) {
      cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
      cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
  });

  const fileFilter = (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|pdf|mp4|doc|docx/;
    const mimetype = allowedTypes.test(file.mimetype);
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());

    if (mimetype && extname) {
      return cb(null, true);
    }
    cb(new Error('Only images, videos, and PDFs are allowed'));
  };

  return multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: {
      fileSize: 20 * 1024 * 1024 // 20MB max
    }
  });
};

module.exports = createUploader;
