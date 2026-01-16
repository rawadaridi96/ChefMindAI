import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'glass_container.dart';

class PaymentFeedbackModal extends StatefulWidget {
  final bool isSuccess;
  final String message;

  const PaymentFeedbackModal({
    super.key,
    required this.isSuccess,
    required this.message,
  });

  static Future<void> show(BuildContext context,
      {required bool isSuccess, required String message}) {
    return showDialog(
      context: context,
      builder: (c) =>
          PaymentFeedbackModal(isSuccess: isSuccess, message: message),
    );
  }

  @override
  State<PaymentFeedbackModal> createState() => _PaymentFeedbackModalState();
}

class _PaymentFeedbackModalState extends State<PaymentFeedbackModal> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    if (widget.isSuccess) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isSuccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 80,
                  color:
                      widget.isSuccess ? AppColors.zestyLime : Colors.redAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isSuccess ? 'Payment Successful!' : 'Payment Failed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.zestyLime,
                    foregroundColor: AppColors.deepCharcoal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        if (widget.isSuccess)
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              AppColors.zestyLime,
              Colors.white,
              AppColors.deepCharcoal
            ],
          ),
      ],
    );
  }
}
