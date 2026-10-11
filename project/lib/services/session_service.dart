import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

class SessionService {
  static const _key = 'auth_token';
  static const _userKey = 'auth_user';
  static Future<void> saveToken(String v) async =>
      (await SharedPreferences.getInstance()).setString(_key, v);
  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  static Future<void> saveUser(Map<String, dynamic> user) async =>
      (await SharedPreferences.getInstance()).setString(
        _userKey,
        jsonEncode(user),
      );
  static Future<Map<String, dynamic>?> user() async {
    final value = (await SharedPreferences.getInstance()).getString(_userKey);
    return value == null ? null : Map<String, dynamic>.from(jsonDecode(value));
  }

  static Future<String> role() async => (await user())?['role'] ?? 'member';
  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
    await preferences.remove(_userKey);
  }
}
