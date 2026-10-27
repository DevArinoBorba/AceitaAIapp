import 'package:flutter/material.dart';

import '../../domain/entities/verdict.dart';
import '../theme/app_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: borderColor ?? AppColors.border),
    );

    // Material (e não Container com cor) para que ListTile, InkWell e
    // expansões pintem o splash corretamente e não disparem a asserção
    // "ListTile background color or ink splashes may be invisible".
    return Material(
      color: color ?? AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class GradePill extends StatelessWidget {
  const GradePill({
    super.key,
    required this.grade,
    this.label,
    this.compact = false,
  });

  final Grade grade;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label ?? grade.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class GradeDot extends StatelessWidget {
  const GradeDot({super.key, required this.grade, this.size = 8});

  final Grade grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradeColor(grade),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 26, bottom: 12),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

InputDecoration appInput({
  required String label,
  String? hint,
  String? suffix,
  Widget? prefixIcon,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.surfaceAlt,
    labelStyle: const TextStyle(color: AppColors.muted),
    hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.65)),
    suffixStyle: const TextStyle(color: AppColors.muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, width: 1.6),
  );
}

/// Botão principal em pílula, usado nas ações de maior peso.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.tonal = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final style = FilledButton.styleFrom(
      backgroundColor: tonal ? AppColors.surfaceAlt : AppColors.primary,
      foregroundColor: tonal ? AppColors.text : AppColors.primaryInk,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: tonal
            ? const BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
    );

    return SizedBox(
      width: expanded ? double.infinity : null,
      child: FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    );
  }
}
