import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:chefmind_ai/core/theme/app_colors.dart';

class BiometricEnrollmentModal extends ConsumerWidget {
  final String email;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const BiometricEnrollmentModal({
    super.key,
    required this.email,
    required this.onEnable,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.zestyLime.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: AppColors.zestyLime,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Enable Fast Login?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  children: [
                    const TextSpan(
                        text:
                            'Would you like to use facial ID or fingerprint for '),
                    TextSpan(
                      text: email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' next time?'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.white54,
                      ),
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onEnable,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Enable',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
