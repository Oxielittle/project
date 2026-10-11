const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const apiRoutes = require('./routes/apiRoutes');
const { notFound, errorHandler } = require('./middleware/errors');
const { setIO } = require('./services/events');
const jwt = require('jsonwebtoken');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
setIO(io);

const PORT = process.env.PORT || 8000;
const MONGO_URI = process.env.MONGO_URI;

// ====================
// Middleware
// ====================

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ====================
// Routes
// ====================

app.use('/api/auth', authRoutes);
app.use('/api', apiRoutes);

// ====================
// Test Route
// ====================

app.get('/', (req, res) => {
    res.json({
        message: 'Server is running'
    });
});

io.use((socket, next) => {
    try { socket.user = jwt.verify(socket.handshake.auth?.token, process.env.JWT_SECRET || 'development-secret'); next(); }
    catch (_) { next(new Error('Authentication required.')); }
});
io.on('connection', (socket) => socket.join(`user:${socket.user.id}`));

app.use(notFound);
app.use(errorHandler);

// ====================
// MongoDB Connection
// ====================

const connectDatabase = async () => {
    try {
        await mongoose.connect(MONGO_URI, { serverSelectionTimeoutMS: 5000 });
        console.log('MongoDB Atlas connected successfully');
    } catch (error) {
        console.warn('MongoDB Atlas unavailable; using local development database.');
        await mongoose.disconnect().catch(() => {});
        await mongoose.connect(process.env.LOCAL_MONGO_URI || 'mongodb://127.0.0.1:27017/project');
        console.log('Local MongoDB connected successfully');
    }
    console.log('Database:', mongoose.connection.name);
    server.listen(PORT, () => console.log(`Server running on port ${PORT}`));
};

connectDatabase().catch((error) => {
    console.error('MongoDB connection failed:');
    console.error(error.message);
});

