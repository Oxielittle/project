import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _key = 'light_mode';
  static final lightMode = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    lightMode.value =
        (await SharedPreferences.getInstance()).getBool(_key) ?? false;
  }

  static Future<void> setLightMode(bool value) async {
    lightMode.value = value;
    await (await SharedPreferences.getInstance()).setBool(_key, value);
  }
}
