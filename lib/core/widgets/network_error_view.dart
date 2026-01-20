import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';

class NetworkErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const NetworkErrorView({
    super.key,
    required this.onRetry,
    this.message,
  });

  static bool isNetworkError(Object error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connection reset') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('clientexception') ||
        errorStr.contains('handshakeexception') ||
        errorStr.contains('host lookup failed') ||
        errorStr.contains('nodename nor servname provided') ||
        errorStr.contains('connection timed out') ||
        errorStr.contains('start of non-boolean');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 24),
            const Text(
              'No Connection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Please check your internet connection and try again.',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zestyLime,
                foregroundColor: AppColors.deepCharcoal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
