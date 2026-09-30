import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// شارة عدد صغيرة وواضحة في الوضعين الفاتح والداكن.
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

/// صف تنقل مسطّح للمستوى أو القسم؛ متعمد أن يكون أخف من البطاقات المرتفعة.
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

    return AnimatedScale(
      scale: _isPressed ? 0.99 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (pressed) {
            if (_isPressed != pressed) setState(() => _isPressed = pressed);
          },
          splashColor: accent.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
            child: Row(
              children: [
                _SectionImage(
                  imageAsset: widget.imageAsset,
                  accent: accent,
                  isGold: widget.isGold,
                  fallbackIcon: widget.fallbackIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.badge != null) ...[
                        const SizedBox(height: 5),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: widget.badge!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Directionality.of(context) == ui.TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// قائمة أقسام موحدة بفواصل هادئة بدل شبكة البطاقات.
class SectionItemList extends StatelessWidget {
  final List<Widget> items;

  const SectionItemList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  items[index],
                  if (index != items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 74,
                      endIndent: 14,
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
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
      decoration: BoxDecoration(color: surface, borderRadius: radius),
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
