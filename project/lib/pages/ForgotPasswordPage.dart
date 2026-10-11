import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController(),
      token = TextEditingController(),
      password = TextEditingController();
  bool requested = false;
  @override
  void dispose() {
    email.dispose();
    token.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> request() async {
    final data = await AuthService.forgotPassword(email.text.trim());
    if (!mounted) return;
    setState(() {
      requested = true;
      if (data['resetToken'] != null) token.text = data['resetToken'];
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(data['message'])));
  }

  Future<void> reset() async {
    await AuthService.resetPassword(token.text.trim(), password.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset. You may now sign in.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Account email'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: request,
          child: const Text('Request reset code'),
        ),
        if (requested) ...[
          const SizedBox(height: 24),
          TextField(
            controller: token,
            decoration: const InputDecoration(labelText: 'Reset code'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password (8+ characters)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: reset, child: const Text('Reset password')),
        ],
      ],
    ),
  );
}
