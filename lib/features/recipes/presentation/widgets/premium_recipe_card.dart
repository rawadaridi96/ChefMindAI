import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PremiumRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onTap;

  const PremiumRecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = recipe['title'] ?? 'Untitled Meal';
    final description = recipe['description'] ?? '';
    final imageUrl = recipe['thumbnail'] ?? recipe['image'];
    final macros = recipe['macros'] as Map<String, dynamic>?;

    // Ingredients Logic
    final ingredients = (recipe['ingredients'] as List?) ?? [];
    int missingCount = 0;
    int totalIngredients = ingredients.length;
    for (var i in ingredients) {
      if (i is Map && i['is_missing'] == true) {
        missingCount++;
      }
    }
    int haveCount = totalIngredients - missingCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280, // Taller, immersive card
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.richBlack,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image (Full Bleed)
            if (imageUrl != null)
              Hero(
                tag: 'recipe_thumb_${recipe['recipe_id'] ?? title}',
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceDark,
                    child: const Icon(Icons.restaurant,
                        color: Colors.white24, size: 64),
                  ),
                ),
              )
            else
              Container(
                color: AppColors.surfaceDark,
                child: const Icon(Icons.restaurant,
                    color: Colors.white24, size: 64),
              ),

            // 2. Gradient Overlay (For Text Readability)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.9), // Darker at bottom
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // 3. Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Badges (Time, Calories if available - skipping for now to keep clean)
                  // We could put badges at top right

                  const Spacer(),

                  // Missing Ingredient Badge (Floating Glass)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: missingCount == 0
                            ? AppColors.zestyLime.withOpacity(0.9)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: missingCount == 0
                                ? AppColors.zestyLime
                                : Colors.white24)),
                    child: Text(
                      missingCount == 0
                          ? AppLocalizations.of(context)!.recipesAvailable
                          : "${haveCount}/${totalIngredients} Have",
                      style: TextStyle(
                        color: missingCount == 0
                            ? AppColors.deepCharcoal
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22, // Larger
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          )
                        ]),
                  ),

                  const SizedBox(height: 8),

                  // Description (Subtle)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Footer: Macros (Glass Row)
                  if (macros != null)
                    Row(
                      children: [
                        _buildMacroPill("Protein", macros['protein']),
                        const SizedBox(width: 8),
                        _buildMacroPill("Carbs", macros['carbs']),
                        const SizedBox(width: 8),
                        _buildMacroPill("Fat", macros['fat']),
                      ],
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroPill(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10, // Glass
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.substring(0, 1), // "P", "C", "F"
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
