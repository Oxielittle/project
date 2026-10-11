import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get host => const String.fromEnvironment(
    'API_HOST',
    defaultValue: kIsWeb ? 'localhost' : '10.0.2.2',
  );
  static String get origin => 'http://$host:8000';
  static String get api => '$origin/api';
}
