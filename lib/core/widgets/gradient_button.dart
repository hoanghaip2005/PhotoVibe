import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.colors = const [AppColors.primary, Color(0xFFEC4899)],
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && onPressed != null;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: colors.first,
      disabledBackgroundColor: AppColors.grouped,
      foregroundColor: effectiveEnabled ? Colors.white : AppColors.muted,
      disabledForegroundColor: AppColors.muted,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    );
    if (icon == null) {
      return FilledButton(
        onPressed: effectiveEnabled ? onPressed : null,
        style: style,
        child: Text(label, overflow: TextOverflow.ellipsis),
      );
    }
    return FilledButton.icon(
      onPressed: effectiveEnabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colors.first,
        disabledBackgroundColor: AppColors.grouped,
        foregroundColor: effectiveEnabled ? Colors.white : AppColors.muted,
        disabledForegroundColor: AppColors.muted,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
