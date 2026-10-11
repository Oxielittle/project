import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'session_service.dart';

class ApiClient {
  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path) async => _decode(
    await http.get(
      Uri.parse('${ApiConfig.api}$path'),
      headers: await _headers(),
    ),
  );
  static Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _decode(
        await http.post(
          Uri.parse('${ApiConfig.api}$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        ),
      );
  static Future<dynamic> patch(String path, Map<String, dynamic> body) async =>
      _decode(
        await http.patch(
          Uri.parse('${ApiConfig.api}$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        ),
      );
  static Future<dynamic> delete(String path) async => _decode(
    await http.delete(
      Uri.parse('${ApiConfig.api}$path'),
      headers: await _headers(),
    ),
  );
  static Future<dynamic> upload(
    String path,
    List<int> bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.api}$path'),
    );
    final token = await SessionService.token();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send();
    return _decode(await http.Response.fromStream(streamed));
  }

  static dynamic _decode(http.Response response) {
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw Exception(
      data['message'] ?? 'Request failed (${response.statusCode}).',
    );
  }
}
