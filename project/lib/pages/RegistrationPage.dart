import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthdayController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final Set<String> _touchedFields = {};

  bool _submitted = false;
  bool _obscurePassword = true;

  void _touchField(String field) {
    setState(() {
      _touchedFields.add(field);
    });
  }

  // First and last names: letters only, minimum 2 characters.
  String? validateName(String? value, String fieldName) {
    final text = value ?? '';

    if (text.trim().isEmpty) {
      return '$fieldName is required.';
    }

    if (!RegExp(r'^[a-zA-Z]{2,}$').hasMatch(text)) {
      return '$fieldName must contain at least 2 letters, with no numbers or special characters.';
    }

    return null;
  }

  // Username: letters and numbers only, minimum 4 characters.
  String? validateUsername(String? value) {
    final text = value ?? '';

    if (text.isEmpty) {
      return 'Username is required.';
    }

    if (!RegExp(r'^[a-zA-Z0-9]{4,}$').hasMatch(text)) {
      return 'Username must have at least 4 characters and contain only letters and numbers.';
    }

    return null;
  }

  // Email: standard email format.
  String? validateEmail(String? value) {
    final text = value ?? '';

    if (text.trim().isEmpty) {
      return 'Email is required.';
    }

    if (!RegExp(
      r'^[a-zA-Z0-9]+([._%+-][a-zA-Z0-9]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$',
    ).hasMatch(text)) {
      return 'Enter a valid email address (e.g. user@example.com).';
    }

    return null;
  }

  // Phone: exactly 11 digits and starts with 09.
  String? validatePhone(String? value) {
    final text = value ?? '';

    if (text.isEmpty) {
      return 'Phone number is required.';
    }

    if (!RegExp(r'^09[0-9]{9}$').hasMatch(text)) {
      return 'Phone number must start with 09 and contain exactly 11 digits.';
    }

    return null;
  }

  // Password: minimum 8 characters, uppercase, lowercase,
  // number, and at least one required special character.
  String? validatePassword(String? value) {
    final text = value ?? '';

    if (text.isEmpty) {
      return 'Password is required.';
    }

    if (text.length < 8) {
      return 'Password must contain at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(text)) {
      return 'Password must contain at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(text)) {
      return 'Password must contain at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(text)) {
      return 'Password must contain at least one number.';
    }

    if (!RegExp(r'[#@$&]').hasMatch(text)) {
      return 'Password must contain at least one of these: #, @, \$, &.';
    }

    // No other special characters are allowed in the password.
    if (!RegExp(r'^[a-zA-Z0-9#@$&]+$').hasMatch(text)) {
      return 'Only letters, numbers, #, @, \$, and & are allowed.';
    }

    return null;
  }

  bool get _isFormValid {
    return validateName(firstNameController.text, 'First name') == null &&
        validateName(lastNameController.text, 'Last name') == null &&
        birthdayController.text.isNotEmpty &&
        validateUsername(usernameController.text) == null &&
        validateEmail(emailController.text) == null &&
        validatePhone(phoneController.text) == null &&
        validatePassword(passwordController.text) == null;
  }

  Future<void> selectBirthday() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
    );

    if (selectedDate != null) {
      setState(() {
        birthdayController.text =
            '${selectedDate.month.toString().padLeft(2, '0')}/'
            '${selectedDate.day.toString().padLeft(2, '0')}/'
            '${selectedDate.year}';
      });
    }
  }

  Future<void> register() async {
    setState(() {
      _submitted = true;

      _touchedFields.addAll([
        'firstName',
        'lastName',
        'birthday',
        'username',
        'email',
        'phone',
        'password',
      ]);
    });

    if (!_formKey.currentState!.validate() || !_isFormValid) {
      return;
    }

    try {
      final result = await AuthService.register(
        firstNameController.text.trim(),
        lastNameController.text.trim(),
        birthdayController.text.trim(),
        usernameController.text.trim(),
        emailController.text.trim(),
        phoneController.text.trim(),
        passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Registration successful.'),
        ),
      );

      // Go back to Login after successful registration.
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthdayController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    'Create an Account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 8),

                const Center(
                  child: Text('Please complete all required fields.'),
                ),

                const SizedBox(height: 30),

                // First Name
                TextFormField(
                  controller: firstNameController,
                  textCapitalization: TextCapitalization.words,
                  onTap: () => _touchField('firstName'),
                  onChanged: (_) {
                    _touchField('firstName');
                  },
                  decoration: fieldDecoration(
                    label: 'First Name *',
                    icon: Icons.person_outline,
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('firstName')) {
                      return null;
                    }

                    return validateName(value, 'First name');
                  },
                ),

                const SizedBox(height: 20),

                // Last Name
                TextFormField(
                  controller: lastNameController,
                  textCapitalization: TextCapitalization.words,
                  onTap: () => _touchField('lastName'),
                  onChanged: (_) {
                    _touchField('lastName');
                  },
                  decoration: fieldDecoration(
                    label: 'Last Name *',
                    icon: Icons.person_outline,
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('lastName')) {
                      return null;
                    }

                    return validateName(value, 'Last name');
                  },
                ),

                const SizedBox(height: 20),

                // Birthday
                TextFormField(
                  controller: birthdayController,
                  readOnly: true,
                  onTap: () {
                    _touchField('birthday');
                    selectBirthday();
                  },
                  decoration: fieldDecoration(
                    label: 'Birthday *',
                    hint: 'Select your birthday',
                    icon: Icons.calendar_today,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('birthday')) {
                      return null;
                    }

                    if (value == null || value.isEmpty) {
                      return 'Birthday is required.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Username
                TextFormField(
                  controller: usernameController,
                  onTap: () => _touchField('username'),
                  onChanged: (_) {
                    _touchField('username');
                  },
                  decoration: fieldDecoration(
                    label: 'Username *',
                    icon: Icons.account_circle_outlined,
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('username')) {
                      return null;
                    }

                    return validateUsername(value);
                  },
                ),

                const SizedBox(height: 20),

                // Email
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  onTap: () => _touchField('email'),
                  onChanged: (_) {
                    _touchField('email');
                  },
                  decoration: fieldDecoration(
                    label: 'Email *',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('email')) {
                      return null;
                    }

                    return validateEmail(value);
                  },
                ),

                const SizedBox(height: 20),

                // Phone Number
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  onTap: () => _touchField('phone'),
                  onChanged: (_) {
                    _touchField('phone');
                  },
                  decoration: fieldDecoration(
                    label: 'Phone Number *',
                    hint: '09XXXXXXXXX',
                    icon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('phone')) {
                      return null;
                    }

                    return validatePhone(value);
                  },
                ),

                const SizedBox(height: 20),

                // Password
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  onTap: () => _touchField('password'),
                  onChanged: (_) {
                    _touchField('password');
                  },
                  decoration: fieldDecoration(
                    label: 'Password *',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (!_touchedFields.contains('password')) {
                      return null;
                    }

                    return validatePassword(value);
                  },
                ),

                const SizedBox(height: 30),

                // Register
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isFormValid ? register : null,
                    child: const Text(
                      'Register',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Back to Login
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
