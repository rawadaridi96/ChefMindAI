import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/subscription/presentation/subscription_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PremiumPaywall extends StatelessWidget {
  final String message;
  final String featureName;
  final String? ctaLabel;

  const PremiumPaywall({
    super.key,
    required this.message,
    required this.featureName,
    this.ctaLabel,
  });

  static Future<void> show(BuildContext context,
      {required String message,
      required String featureName,
      String? ctaLabel}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => PremiumPaywall(
        message: message,
        featureName: featureName,
        ctaLabel: ctaLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipPath(
        clipper: const _ValleyClipper(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
              decoration: BoxDecoration(
                color:
                    AppColors.surfaceDark.withOpacity(0.95), // Lighter & Opaque
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.15), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.zestyLime.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.zestyLime.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(FontAwesomeIcons.crown,
                        color: AppColors.zestyLime, size: 32),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    AppLocalizations.of(context)!.premiumLimitReached,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Message
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Upgrade Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close wall
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SubscriptionScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        ctaLabel ??
                            AppLocalizations.of(context)!.premiumUpgradeToSous,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Close Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.premiumNotNow,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
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

// Reusing the ValleyClipper from AuthSheet for consistency
class _ValleyClipper extends CustomClipper<Path> {
  const _ValleyClipper();

  @override
  Path getClip(Size size) {
    final double width = size.width;
    final double height = size.height;
    const double radius = 40.0;
    const double notchRadius = 45.0;

    final path = Path();
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo((width / 2) - notchRadius - 10, 0);
    path.quadraticBezierTo(
        (width / 2) - notchRadius, 0, (width / 2) - notchRadius + 5, 10);
    path.arcToPoint(
      Offset((width / 2) + notchRadius - 5, 10),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(
        (width / 2) + notchRadius, 0, (width / 2) + notchRadius + 10, 0);
    path.lineTo(width - radius, 0);
    path.quadraticBezierTo(width, 0, width, radius);
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
