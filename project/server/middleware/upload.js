const multer = require('multer');
const path = require('path');
const fs = require('fs');

const directory = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(directory, { recursive: true });
const storage = multer.diskStorage({
  destination: (_, __, callback) => callback(null, directory),
  filename: (_, file, callback) => callback(null, `${Date.now()}-${Math.random().toString(36).slice(2)}${path.extname(file.originalname)}`),
});
module.exports = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 },
  fileFilter: (_, file, callback) => callback(null, !file.mimetype.includes('javascript') && !file.mimetype.includes('html')),
});
