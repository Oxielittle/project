const mongoose = require('mongoose');

const authSchema = new mongoose.Schema(
{
firstName: {
type: String,
required: true,
trim: true,
},


    lastName: {
        type: String,
        required: true,
        trim: true,
    },

    birthday: {
        type: Date,
        required: true,
    },

    username: {
        type: String,
        required: true,
        unique: true,
        trim: true,
    },

    email: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true,
    },

    phone: {
        type: String,
        required: true,
        unique: true,
        trim: true,
    },

    password: {
        type: String,
        required: true,
    },
},
{
    timestamps: true,
}


);

const Auth = mongoose.model('Auth', authSchema);

module.exports = Auth;
