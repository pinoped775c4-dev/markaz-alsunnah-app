import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// شارة عدد صغيرة — تظل واضحة في الوضعين الفاتح والداكن.
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
    final scheme = Theme.of(context).colorScheme;
    final foreground = !active
        ? scheme.onSurfaceVariant
        : gold
            ? (scheme.brightness == Brightness.dark
                ? AppColors.goldSoft
                : AppColors.goldDark)
            : scheme.primary;
    final background = !active
        ? scheme.surfaceContainerHighest
        : gold
            ? AppColors.gold.withValues(
                alpha: scheme.brightness == Brightness.dark ? 0.18 : 0.12,
              )
            : scheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// بطاقة قسم تفاعلية بدل الأيقونة الدائرية الصغيرة.
/// تتشاركها لوحات المعلم والمشرف حتى يبقى شكل الأقسام موحدًا.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = widget.isGold ? AppColors.gold : scheme.primary;
    final radius = BorderRadius.circular(AppRadius.lg);

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: Material(
        color: scheme.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (pressed) {
            if (_isPressed != pressed) setState(() => _isPressed = pressed);
          },
          borderRadius: radius,
          splashColor: accent.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: scheme.brightness == Brightness.dark ? 0.08 : 0.035,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  _SectionImage(
                    imageAsset: widget.imageAsset,
                    accent: accent,
                    isGold: widget.isGold,
                    fallbackIcon: widget.fallbackIcon,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: widget.badge!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Directionality.of(context) == ui.TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شبكة متجاوبة للبطاقات؛ عمودان على الهاتف وثلاثة على الشاشات العريضة.
class SectionItemGrid extends StatelessWidget {
  final List<Widget> items;

  const SectionItemGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 104,
          ),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }
}

class _SectionImage extends StatelessWidget {
  final String? imageAsset;
  final Color accent;
  final bool isGold;
  final IconData fallbackIcon;

  const _SectionImage({
    required this.imageAsset,
    required this.accent,
    required this.isGold,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.md);
    final surface = isGold
        ? AppColors.gold.withValues(
            alpha: scheme.brightness == Brightness.dark ? 0.18 : 0.12,
          )
        : scheme.primaryContainer;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: imageAsset == null
            ? _fallback(context)
            : Image.asset(
                imageAsset!,
                fit: BoxFit.cover,
                cacheWidth: 224,
                cacheHeight: 224,
                errorBuilder: (_, __, ___) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isGold
        ? AppColors.gold.withValues(
            alpha: scheme.brightness == Brightness.dark ? 0.18 : 0.12,
          )
        : scheme.primaryContainer;
    return ColoredBox(
      color: background,
      child: Icon(
        isGold ? Icons.menu_book_rounded : fallbackIcon,
        color: accent,
        size: 26,
      ),
    );
  }
}
