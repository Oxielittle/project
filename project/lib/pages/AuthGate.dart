import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/session_service.dart';
import 'AppShell.dart';
import 'LoginPage.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget? page;
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final token = await SessionService.token();
    if (token == null) {
      if (mounted) setState(() => page = const LoginPage());
      return;
    }
    try {
      final data = await ApiClient.get('/auth/me');
      if (data['user'] != null) await SessionService.saveUser(data['user']);
      if (mounted) setState(() => page = const AppShell());
    } catch (_) {
      await SessionService.clear();
      if (mounted) setState(() => page = const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) =>
      page ?? const Scaffold(body: Center(child: CircularProgressIndicator()));
}
