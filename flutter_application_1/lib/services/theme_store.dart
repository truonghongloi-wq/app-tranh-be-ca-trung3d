import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore {
  static const _key = 'theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'dark') {
      mode.value = ThemeMode.dark;
    }
  }

  static Future<void> toggle() async {
    final next = mode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }

  static bool get isDark => mode.value == ThemeMode.dark;

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    // Material 3 bỏ qua primarySwatch: phải khai báo colorScheme, nếu không
    // các widget mặc định (nút, bottom sheet, dialog...) dùng tông tím gốc.
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      primary: const Color(0xFF2563EB),
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    primaryColor: const Color(0xFF2563EB),
    scaffoldBackgroundColor: const Color(0xFFF4F7F9),
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardColor: Colors.white,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF2563EB),
      unselectedItemColor: Colors.grey,
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.dark,
      primary: const Color(0xFF5CC1FF),
      surface: const Color(0xFF1E1E1E),
      surfaceTint: Colors.transparent,
    ),
    primaryColor: const Color(0xFF2563EB),
    scaffoldBackgroundColor: const Color(0xFF121212),
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Color(0xFF1E1E1E),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardColor: const Color(0xFF1E1E1E),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedItemColor: Color(0xFF5CC1FF),
      unselectedItemColor: Colors.grey,
    ),
    dividerColor: Colors.white12,
  );
}
