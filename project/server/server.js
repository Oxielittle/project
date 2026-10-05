const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');

const app = express();

const PORT = process.env.PORT || 8000;
const MONGO_URI = process.env.MONGO_URI;

// ====================
// Middleware
// ====================

app.use(cors());
app.use(express.json());

// ====================
// Routes
// ====================

app.use('/api/auth', authRoutes);

// ====================
// Test Route
// ====================

app.get('/', (req, res) => {
    res.json({
        message: 'Server is running'
    });
});

// ====================
// MongoDB Connection
// ====================

mongoose
    .connect(MONGO_URI)
    .then(() => {
        console.log('MongoDB Atlas connected successfully');
        console.log('Database:', mongoose.connection.name);

        app.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
        });
    })
    .catch((error) => {
        console.error('MongoDB connection failed:');
        console.error(error.message);
    });

