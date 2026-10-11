import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session_service.dart';
import 'api_client.dart';

class AuthService {
  static String get baseUrl => '${ApiConfig.api}/auth';

  static Future<Map<String, dynamic>> register(
    String firstName,
    String lastName,
    String birthday,
    String username,
    String email,
    String phone,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'birthday': birthday,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      if (data['token'] != null) await SessionService.saveToken(data['token']);
      if (data['user'] != null) await SessionService.saveUser(data['user']);
      return data;
    }

    throw Exception(data['message'] ?? 'Registration failed.');
  }

  static Future<Map<String, dynamic>> login(
    String usernameOrEmail,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data['token'] != null) await SessionService.saveToken(data['token']);
      if (data['user'] != null) await SessionService.saveUser(data['user']);
      return data;
    }

    throw Exception(data['message'] ?? 'Login failed.');
  }

  static Future<void> logout() => SessionService.clear();
  static Future<Map<String, dynamic>> forgotPassword(String email) async =>
      Map<String, dynamic>.from(
        await ApiClient.post('/auth/forgot-password', {'email': email}),
      );
  static Future<void> resetPassword(String token, String password) async =>
      ApiClient.post('/auth/reset-password', {
        'token': token,
        'password': password,
      });
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> body,
  ) async {
    final data = Map<String, dynamic>.from(
      await ApiClient.patch('/auth/me', body),
    );
    await SessionService.saveUser(Map<String, dynamic>.from(data['user']));
    return data;
  }

  static Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async => ApiClient.patch('/auth/change-password', {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  });
}
