import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.all(16.0),
    this.blur = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
