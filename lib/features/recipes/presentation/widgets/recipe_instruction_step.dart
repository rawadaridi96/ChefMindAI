import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';

class RecipeInstructionStep extends StatelessWidget {
  final int stepNumber;
  final String text;

  const RecipeInstructionStep({
    super.key,
    required this.stepNumber,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Number
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.zestyLime,
              shape: BoxShape.circle,
            ),
            child: Text(
              "$stepNumber",
              style: const TextStyle(
                color: AppColors.deepCharcoal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Instruction Text
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white, // High contrast text
                height: 1.5,
                fontSize: 16,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
