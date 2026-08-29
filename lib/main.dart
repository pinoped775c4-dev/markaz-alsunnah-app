import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/teacher/teacher_home_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة التاريخ بالعربية والإنجليزية
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // تحميل الإعدادات المحفوظة (الوضع الليلي / اللغة)
  final settings = SettingsService();
  await settings.load();

  // تهيئة Firebase (مع التعامل مع فشل الإعداد مؤقتاً)
  bool firebaseReady = DefaultFirebaseOptions.isConfigured;
  if (firebaseReady) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      firebaseReady = false;
      debugPrint('Firebase initialization failed: $e');
    }
  }

  runApp(
    IslamicCenterApp(firebaseReady: firebaseReady, settings: settings),
  );
}

class IslamicCenterApp extends StatelessWidget {
  final bool firebaseReady;
  final SettingsService settings;

  const IslamicCenterApp({
    super.key,
    required this.firebaseReady,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) => MaterialApp(
          title: 'مركز السنة للعلوم الشرعية وتأهيل الدعاة',
          debugShowCheckedModeBanner: false,

          // دعم اللغتين العربية (افتراضي) والإنجليزية
          locale: settings.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,

          home: firebaseReady
              ? const AppRouter()
              : const _FirebaseSetupScreen(),
        ),
      ),
    );
  }
}

/// شاشة توضيح عند غياب إعدادات Firebase للمنصة الحالية (ويب غالباً)
class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 120),
              const SizedBox(height: 24),
              Text(
                'إعداد Firebase للويب مطلوب',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'تم ربط أندرويد بنجاح.\n'
                'لتشغيل معاينة الويب: سجّل تطبيق Web في Firebase Console '
                'للمشروع calculator-7ae7b38d ثم زوّد قيم apiKey و appId.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الموجه الرئيسي: Splash ← فحص الجلسة ← توجيه حسب الدور
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _minSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    // عرض السبلاش 3 ثوانٍ على الأقل أثناء فحص الجلسة
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
    // فحص الجلسة الحالية بالتوازي
    Future.microtask(() {
      if (mounted) context.read<AuthService>().checkExistingSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // السبلاش يبقى حتى: (اكتمال فحص الجلسة) + (مرور 3 ثوانٍ)
    final showSplash = !_minSplashElapsed || !auth.isInitialized;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: showSplash
          ? const SplashScreen(key: ValueKey('splash'))
          : _buildDestination(auth),
    );
  }

  Widget _buildDestination(AuthService auth) {
    final user = auth.currentUser;

    if (user == null) {
      return const LoginScreen(key: ValueKey('login'));
    }

    if (user.isAdmin) {
      return const AdminShell(key: ValueKey('admin'));
    }

    return const TeacherHomeScreen(key: ValueKey('teacher'));
  }
}
