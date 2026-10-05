import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://localhost:8000/api/auth';

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

    print('REGISTER URL: $url');

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

    print('REGISTER STATUS: ${response.statusCode}');
    print('REGISTER RESPONSE: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
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
      return data;
    }

    throw Exception(data['message'] ?? 'Login failed.');
  }
}
