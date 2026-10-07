import 'package:flutter/material.dart';

import '../core/theme.dart';

/// شارة عدد صغيرة — تُستخدم تحت الأيقونات الدائرية
/// (نفس تصميم شارة عدد الطلاب السابقة)
class CountBadge extends StatelessWidget {
  final String text;
  final bool active;
  final bool gold;

  const CountBadge({
    super.key,
    required this.text,
    required this.active,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? (gold
                ? AppColors.goldSurface
                : AppColors.primarySurface)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active
              ? (gold ? AppColors.goldDark : AppColors.primaryDark)
              : AppColors.inkMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// أيقونة دائرية بصورة مدموجة — التصميم الموحّد لأقسام حساب المعلم:
/// الدائرة (صورة + حافة ذهبية + ظل ناعم) ثم اسم القسم ثم شارة اختيارية.
///
/// تُستخدم في: مستويات حساب المعلم، وقسمي "المعلمون" و"الطلاب"
/// في حساب المشرف، وشاشة "حساب المعلم".
class CircleSectionItem extends StatefulWidget {
  final String? imageAsset;
  final String label;
  final Widget? badge;
  final bool isGold;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  const CircleSectionItem({
    super.key,
    this.imageAsset,
    required this.label,
    this.badge,
    this.isGold = false,
    this.fallbackIcon = Icons.school_rounded,
    required this.onTap,
  });

  @override
  State<CircleSectionItem> createState() => _CircleSectionItemState();
}

class _CircleSectionItemState extends State<CircleSectionItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = widget.isGold ? AppColors.gold : AppColors.primary;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (pressed) {
          if (_isPressed != pressed) setState(() => _isPressed = pressed);
        },
        borderRadius: radius,
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.04),
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                // الدائرة بالصورة المدموجة
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isGold
                          ? AppColors.gold
                          : AppColors.goldSoft,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.imageAsset != null
                        ? Image.asset(
                            widget.imageAsset!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackIcon(),
                          )
                        : _fallbackIcon(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall
                      ?.copyWith(fontSize: 12.5, height: 1.25),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(height: 4),
                  widget.badge!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: widget.isGold ? AppColors.goldSurface : AppColors.primarySurface,
      child: Icon(
        widget.isGold ? Icons.menu_book_rounded : widget.fallbackIcon,
        color: widget.isGold ? AppColors.goldDark : AppColors.primary,
        size: 32,
      ),
    );
  }
}
