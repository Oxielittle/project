const notFound = (req, res) => res.status(404).json({ message: 'Route not found.' });
const errorHandler = (err, req, res, next) => {
  console.error(err);
  if (res.headersSent) return next(err);
  res.status(err.status || 500).json({ message: err.message || 'Internal server error.' });
};
module.exports = { notFound, errorHandler };
