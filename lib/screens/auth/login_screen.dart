import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';

/// شاشة تسجيل الدخول الفاخرة — هوية المركز الكاملة
class LoginScreen extends StatefulWidget {
  final String? initialMessage;

  const LoginScreen({super.key, this.initialMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final result = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  Future<void> _forgotPassword() async {
    // إعادة تعيين كلمة المرور تتم من قِبل إدارة المركز فقط
    setState(() => _errorMessage = null);
    _showContactAdminDialog();
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text('التواصل مع الإدارة',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'الحسابات تُنشأ من قِبل إدارة المركز فقط.\n'
              'إذا كنت معلماً جديداً أو واجهت مشكلة في الدخول، '
              'يرجى مراجعة إدارة المركز مباشرة.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDFEFD), Color(0xFFEFF6F2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // الشعار الرسمي داخل دائرة أنيقة
                    Center(
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                              color: AppColors.goldSoft, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Image.asset(AppConstants.logoAsset,
                                fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.centerName,
                      textAlign: TextAlign.center,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // بطاقة تسجيل الدخول
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.lineSoft),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'للمديرين والمعلمين فقط',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),

                          // رسالة الخطأ
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorSurface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: AppColors.error, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // البريد الإلكتروني
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: ui.TextDirection.ltr,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon:
                                  Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'البريد الإلكتروني مطلوب';
                              }
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(value.trim())) {
                                return 'صيغة البريد الإلكتروني غير صحيحة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // كلمة المرور
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: ui.TextDirection.ltr,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'كلمة المرور مطلوبة';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _signIn(),
                          ),

                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed:
                                  _isLoading ? null : _forgotPassword,
                              child: const Text('نسيت كلمة المرور؟'),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // زر الدخول
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text('تسجيل الدخول'),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // بانر المعلومات الرسمي
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.goldSurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color:
                                AppColors.gold.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined,
                              color: AppColors.gold, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'لا يوجد تسجيل ذاتي في التطبيق.\nالحسابات تُنشأ من قِبل إدارة المركز فقط.',
                              style: textTheme.bodySmall
                                  ?.copyWith(height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextButton.icon(
                      onPressed: _showContactAdminDialog,
                      icon: const Icon(Icons.support_agent_rounded,
                          size: 19),
                      label: const Text('التواصل مع الإدارة'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
