import 'package:flutter/material.dart';

/// نظام التصميم الاحترافي لمركز السنة للعلوم الشرعية وتأهيل الدعاة
/// هوية: أخضر زمردي عميق + ذهبي دافئ + رمادي حجري فاتح
class AppColors {
  AppColors._();

  // الهوية الأساسية — زمردي عميق مستلهم من شعار المركز
  static const Color primary = Color(0xFF0E7C5B);
  static const Color primaryDark = Color(0xFF0A5C44);
  static const Color primarySoft = Color(0xFF3AA385);
  static const Color primarySurface = Color(0xFFE8F5F0);
  static const Color primaryBorder = Color(0xFFCBE8DD);

  // الذهبي الدافئ
  static const Color gold = Color(0xFFC09A3E);
  static const Color goldDark = Color(0xFFA17F2C);
  static const Color goldSoft = Color(0xFFE4CF95);
  static const Color goldSurface = Color(0xFFFAF3E1);

  // المحايدة
  static const Color background = Color(0xFFF5F7F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAF9);
  static const Color ink = Color(0xFF14201C);
  static const Color inkSecondary = Color(0xFF5C6B65);
  static const Color inkMuted = Color(0xFF8A9A92);
  static const Color line = Color(0xFFE4EAE7);
  static const Color lineSoft = Color(0xFFEEF2F0);

  // الدلالية
  static const Color success = Color(0xFF1F9D63);
  static const Color successSurface = Color(0xFFE3F5EC);
  static const Color error = Color(0xFFD84A4A);
  static const Color errorSurface = Color(0xFFFBEBEB);
  static const Color warning = Color(0xFFE39A2D);
  static const Color warningSurface = Color(0xFFFCF3E3);

  // تدرجات
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E7C5B), Color(0xFF0A5C44)],
  );
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4B45A), Color(0xFFC09A3E)],
  );

  // الداكن
  static const Color darkBackground = Color(0xFF0C1311);
  static const Color darkSurface = Color(0xFF15201C);
  static const Color darkSurfaceAlt = Color(0xFF1B2A25);
  static const Color darkInk = Color(0xFFE9F0EC);
  static const Color darkInkSecondary = Color(0xFF93A69E);
  static const Color darkLine = Color(0xFF243630);
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(TextTheme base, Color ink, Color secondary) {
    // خط IBM Plex Sans Arabic مُسجَّل كأصل محلي (assets/fonts) —
    // لا جلب من الشبكة عند التشغيل (كان سبب بطء أول عرض وتحذيرات أداء)
    final t = base.apply(fontFamily: 'IBM Plex Sans Arabic');
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
          fontWeight: FontWeight.bold, color: ink, height: 1.3),
      headlineSmall: t.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold, color: ink, height: 1.3),
      titleLarge: t.titleLarge?.copyWith(
          fontWeight: FontWeight.bold, color: ink, fontSize: 20),
      titleMedium: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w600, color: ink, fontSize: 16.5),
      titleSmall: t.titleSmall?.copyWith(
          fontWeight: FontWeight.w600, color: ink, fontSize: 14.5),
      bodyLarge: t.bodyLarge?.copyWith(color: ink, height: 1.55),
      bodyMedium: t.bodyMedium
          ?.copyWith(color: ink, height: 1.55, fontSize: 14.5),
      bodySmall: t.bodySmall
          ?.copyWith(color: secondary, height: 1.5, fontSize: 12.5),
      labelLarge: t.labelLarge
          ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        error: AppColors.error,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme =
        _textTheme(base.textTheme, AppColors.ink, AppColors.inkSecondary);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.line,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.lineSoft, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: AppColors.primaryBorder),
          backgroundColor: AppColors.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.6),
        ),
        labelStyle: textTheme.bodyMedium
            ?.copyWith(color: AppColors.inkSecondary),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium
            ?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lineSoft,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lineSoft,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.inkSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodyMedium,
        dividerColor: AppColors.lineSoft,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.primarySurface,
        labelStyle:
            textTheme.bodySmall?.copyWith(color: AppColors.primaryDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primarySoft,
        secondary: AppColors.gold,
        error: AppColors.error,
        surface: AppColors.darkSurface,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
    );

    final textTheme = _textTheme(
        base.textTheme, AppColors.darkInk, AppColors.darkInkSecondary);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.darkLine, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkLine,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}
