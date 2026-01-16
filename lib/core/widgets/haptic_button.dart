import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class HapticButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData? icon;
  final bool isPrimary;

  const HapticButton({
    super.key,
    required this.onTap,
    required this.label,
    this.icon,
    this.isPrimary = true,
  });

  void _handleTap() {
    HapticFeedback.lightImpact();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.zestyLime : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(30),
          border: isPrimary ? null : Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isPrimary
                    ? AppColors.deepCharcoal
                    : AppColors.electricWhite,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? AppColors.deepCharcoal
                    : AppColors.electricWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
