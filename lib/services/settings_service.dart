import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// متحكم الإعدادات العامة: الوضع الليلي/النهاري + اللغة
/// يُخزَّن الاختيار في SharedPreferences ليبقى بعد إغلاق التطبيق
class SettingsService extends ChangeNotifier {
  static const _kThemeMode = 'settings_theme_mode';
  static const _kLocale = 'settings_locale';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isArabic => _locale.languageCode == 'ar';

  /// تحميل الإعدادات المحفوظة (يُستدعى قبل runApp)
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_kThemeMode);
      if (mode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (mode == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }

      final lang = prefs.getString(_kLocale);
      if (lang == 'en') {
        _locale = const Locale('en');
      } else {
        _locale = const Locale('ar');
      }
      notifyListeners();
    } catch (_) {
      // القيم الافتراضية كافية عند الفشل
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kThemeMode,
        mode == ThemeMode.dark
            ? 'dark'
            : mode == ThemeMode.system
                ? 'system'
                : 'light',
      );
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocale, locale.languageCode);
    } catch (_) {}
  }
}
