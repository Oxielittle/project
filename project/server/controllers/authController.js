const bcrypt = require('bcryptjs');
const Auth = require('../models/authModel');

const registerUser = async (req, res) => {
try {
    console.log('Register request received:', req.body);
const {
firstName,
lastName,
birthday,
username,
email,
phone,
password
} = req.body;


    // Check required fields
    if (
        !firstName ||
        !lastName ||
        !birthday ||
        !username ||
        !email ||
        !phone ||
        !password
    ) {
        return res.status(400).json({
            message: 'All fields are required.'
        });
    }

    // Check if username already exists
    const existingUsername = await Auth.findOne({ username });

    if (existingUsername) {
        return res.status(409).json({
            message: 'Username is already taken.'
        });
    }

    // Check if email already exists
    const existingEmail = await Auth.findOne({
        email: email.toLowerCase()
    });

    if (existingEmail) {
        return res.status(409).json({
            message: 'Email is already registered.'
        });
    }

    // Check if phone already exists
    const existingPhone = await Auth.findOne({ phone });

    if (existingPhone) {
        return res.status(409).json({
            message: 'Phone number is already registered.'
        });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const newUser = new Auth({
        firstName,
        lastName,
        birthday,
        username,
        email: email.toLowerCase(),
        phone,
        password: hashedPassword
    });

    // Save user to MongoDB
    await newUser.save();

    return res.status(201).json({
        message: 'Registration successful.',
        user: {
            id: newUser._id,
            firstName: newUser.firstName,
            lastName: newUser.lastName,
            birthday: newUser.birthday,
            username: newUser.username,
            email: newUser.email,
            phone: newUser.phone
        }
    });

} catch (error) {
    console.error('Registration error:', error);

    return res.status(500).json({
        message: 'Server error during registration.'
    });
}


};

const loginUser = async (req, res) => {
try {
const { usernameOrEmail, password } = req.body;


    // Check required fields
    if (!usernameOrEmail || !password) {
        return res.status(400).json({
            message: 'Username/email and password are required.'
        });
    }

    // Find user by username OR email
    const user = await Auth.findOne({
        $or: [
            { username: usernameOrEmail },
            { email: usernameOrEmail.toLowerCase() }
        ]
    });

    // User doesn't exist
    if (!user) {
        return res.status(401).json({
            message: 'Invalid username/email or password.'
        });
    }

    // Compare password
    const passwordMatch = await bcrypt.compare(
        password,
        user.password
    );

    if (!passwordMatch) {
        return res.status(401).json({
            message: 'Invalid username/email or password.'
        });
    }

    // Successful login
    return res.status(200).json({
        message: 'Login successful.',
        user: {
            id: user._id,
            firstName: user.firstName,
            lastName: user.lastName,
            birthday: user.birthday,
            username: user.username,
            email: user.email,
            phone: user.phone
        }
    });

} catch (error) {
    console.error('Login error:', error);

    return res.status(500).json({
        message: 'Server error during login.'
    });
}


};

module.exports = {
registerUser,
loginUser
};
