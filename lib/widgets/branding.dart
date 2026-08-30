import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// خلفية مائية بشعار المركز + نقوش إسلامية هندسية خفيفة وشفافة
///
/// الاستخدام:
/// ```dart
/// Scaffold(body: WatermarkedBackground(child: MyContent()))
/// ```
class WatermarkedBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double size;

  /// إظهار نقوش الزخرفة الإسلامية خلف المحتوى
  final bool withPattern;

  /// شفافية النقوش (خفيفة جداً مثل العلامة المائية)
  final double patternOpacity;

  const WatermarkedBackground({
    super.key,
    required this.child,
    this.opacity = 0.055,
    this.size = 420,
    this.withPattern = true,
    this.patternOpacity = 0.035,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // ===== نقوش الزخرفة الإسلامية (تغطي الشاشة كاملة) =====
        if (withPattern)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                // isComplex: يُخزَّن النقش في طبقة Skia مؤقتة بدل إعادة رسمه
                // في كل إطار — النقش شفاف وثابت فلا داعي لإعادة الرسم
                isComplex: true,
                willChange: false,
                painter: _IslamicPatternPainter(
                  color: isDark
                      ? Colors.white.withValues(alpha: patternOpacity * 0.9)
                      : AppColors.primary
                          .withValues(alpha: patternOpacity),
                  accent: AppColors.gold.withValues(alpha: patternOpacity * 0.8),
                ),
              ),
            ),
          ),

        // ===== الشعار المائي في المنتصف =====
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  AppConstants.logoAsset,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// رسّام نقوش هندسية إسلامية (نجمة ثمانية داخل شبكة مثمنات)
class _IslamicPatternPainter extends CustomPainter {
  final Color color;
  final Color accent;

  _IslamicPatternPainter({required this.color, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final accentPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // بلاطة أكبر = عناصر أقل بكثير لكل إطار — النقش يُرسم مرة واحدة
    // ثم يُخزَّن في طبقة Skia (isComplex hint أسفل)
    const double tile = 160;
    final int cols = (size.width / tile).ceil() + 1;
    final int rows = (size.height / tile).ceil() + 1;

    for (int r = -1; r <= rows; r++) {
      for (int c = -1; c <= cols; c++) {
        // إزاحة الصفوف الفردية لنمط متداخل
        final dx = c * tile + (r.isOdd ? tile / 2 : 0);
        final dy = r * tile;
        final center = Offset(dx + tile / 2, dy + tile / 2);
        _drawEightPointStar(canvas, center, tile * 0.34, linePaint);
        // حلقة المثمنات على البلاطات الزوجية فقط — يوفر نصف الرسم
        if ((r + c).isEven) {
          _drawOctagonRing(canvas, center, tile * 0.46, accentPaint);
        }
      }
    }
  }

  /// نجمة ثمانية = مربعان متقاطعان بزاوية 45°
  void _drawEightPointStar(
      Canvas canvas, Offset center, double radius, Paint paint) {
    for (final rotation in [0.0, math.pi / 4]) {
      final path = Path();
      for (int i = 0; i < 4; i++) {
        final angle = rotation + i * math.pi / 2;
        final point = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    // دائرة صغيرة في مركز النجمة
    canvas.drawCircle(center, radius * 0.16, paint);
  }

  /// إطار مثمن حول النجمة
  void _drawOctagonRing(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = math.pi / 8 + i * math.pi / 4;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}

/// شعار المركز داخل إطار دائري أنيق

/// شعار المركز داخل إطار دائري أنيق
class CircularLogo extends StatelessWidget {
  final double size;
  final bool elevated;

  const CircularLogo({super.key, this.size = 88, this.elevated = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.goldSoft, width: 2.5),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            AppConstants.logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.mosque_rounded,
              size: size * 0.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// صيغة الجمع العربية الصحيحة لعدد الطلاب
/// 1 طالب • 2 طالبان • 3-10 طلاب • 11+ طالباً
String studentsCountLabel(int count) {
  if (count <= 0) return 'لا يوجد طلاب';
  if (count == 1) return 'طالب واحد';
  if (count == 2) return 'طالبان';
  if (count >= 3 && count <= 10) return '$count طلاب';
  return '$count طالباً';
}

/// صورة المستخدم الشخصية (Base64 من Firestore) مع بديل أنيق
class ProfileAvatar extends StatelessWidget {
  final String? photoBase64;
  final String name;
  final double size;

  const ProfileAvatar({
    super.key,
    this.photoBase64,
    required this.name,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(photoBase64!));
      } catch (_) {
        image = null;
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: image == null ? AppColors.primaryGradient : null,
        border: Border.all(color: AppColors.goldSoft, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
       ],
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(
              name.isNotEmpty ? name[0] : '؟',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.42,
              ),
            )
          : null,
    );
  }
}
