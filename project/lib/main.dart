import 'package:flutter/material.dart';

import 'pages/AuthGate.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const electricBlue = Color(0xFF176BFF);
  static const navy = Color(0xFF020817);
  static const surface = Color(0xFF081426);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ThemeService.lightMode,
    builder: (_, lightMode, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Management System',
      themeMode: lightMode ? ThemeMode.light : ThemeMode.dark,
      darkTheme: _darkTheme(),
      theme: _lightTheme(),
      home: const AuthGate(),
    ),
  );

  ThemeData _darkTheme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: electricBlue,
          brightness: Brightness.dark,
          surface: surface,
        ).copyWith(
          primary: electricBlue,
          secondary: const Color(0xFF55A3FF),
          surface: surface,
          surfaceContainer: const Color(0xFF0B1A31),
          surfaceContainerLow: const Color(0xFF071222),
          outline: const Color(0xFF1D3B67),
        );
    return _baseTheme(scheme).copyWith(
      scaffoldBackgroundColor: navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF06101F),
        indicatorColor: electricBlue.withValues(alpha: .22),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF73B4FF)
                : const Color(0xFF8796AC),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF8796AC),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: electricBlue,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return _baseTheme(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F7FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F7FC),
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  ThemeData _baseTheme(ColorScheme scheme) => ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline.withValues(alpha: .55)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: .75)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outline.withValues(alpha: .6)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: .5)),
  );
}
