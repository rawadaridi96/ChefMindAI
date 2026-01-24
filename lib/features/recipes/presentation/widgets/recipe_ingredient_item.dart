import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';

class RecipeIngredientItem extends StatelessWidget {
  final String name;
  final String amount;
  final bool isMissing;
  final VoidCallback onAddToCart;

  const RecipeIngredientItem({
    super.key,
    required this.name,
    required this.amount,
    required this.isMissing,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Separate Amount and Unit if possible, or just display cleaner
    // For now, amount is the pre-scaled string passed in.

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), // Subtle card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center, // Center vertically for clean look
        children: [
          // Icon (Missing vs Check)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              isMissing ? Icons.circle_outlined : Icons.check_circle,
              color: isMissing ? Colors.white24 : AppColors.zestyLime,
              size: 20,
            ),
          ),

          // Content
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  // Amount (Bold)
                  if (amount.isNotEmpty)
                    TextSpan(
                      text: "$amount ",
                      style: const TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  // Name (Regular)
                  TextSpan(
                    text: name,
                    style: TextStyle(
                      color: isMissing ? Colors.white60 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      decoration: (!isMissing &&
                              !name.toLowerCase().contains("missing"))
                          ? null // TextDecoration.lineThrough // Optional: strike through if checked?
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Add to Cart Action
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, size: 20),
            color: Colors.white30,
            tooltip: "Add to cart",
            onPressed: onAddToCart,
          ),
        ],
      ),
    );
  }
}
