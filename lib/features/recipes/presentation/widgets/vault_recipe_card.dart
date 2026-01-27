import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VaultRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String deleteLabel;

  const VaultRecipeCard({
    super.key,
    required this.recipe,
    required this.isGrid,
    required this.onTap,
    required this.onDelete,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return _buildGridCard(context);
    } else {
      return _buildListCard(context);
    }
  }

  Widget _buildListCard(BuildContext context) {
    // Extract data
    final title = recipe['title'] ?? 'Untitled';
    final description = recipe['description'] ?? '';
    final isLink = recipe['type'] == 'link';
    final platform = recipe['platform'];
    final calories = recipe['calories'];
    final createdAt =
        recipe['created_at']?.toString().split('T')[0] ?? 'Recently';

    return Padding(
      padding: const EdgeInsets.only(
          bottom: 16), // More spacing for immersive feeling
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 220, // Taller card for immersive feel
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
              if (_getImageProvider(recipe) != null)
                Hero(
                  tag: 'recipe_thumb_${recipe['recipe_id'] ?? title}',
                  child: Image(
                    image: _getImageProvider(recipe)!,
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
                  child: Center(
                    child: Icon(
                      isLink ? Icons.link : Icons.restaurant_menu_rounded,
                      color: AppColors.zestyLime.withOpacity(0.3),
                      size: 64,
                    ),
                  ),
                ),

              // 2. Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(
                          0.2), // Light shadow for delete button visibility
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.9), // Dark bottom for text
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
                    // Title
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            )
                          ]),
                    ),

                    const SizedBox(height: 6),

                    // Description
                    Text(
                      description.isNotEmpty
                          ? description
                          : (isLink ? 'Saved Link' : 'Delicious Recipe'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Footer Row (Scrollable to prevent overflow)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildGlassBadge(isLink ? "LINK" : "RECIPE"),
                          const SizedBox(width: 8),
                          _buildMiniBadge(Icons.calendar_today, createdAt),
                          if (isLink && platform != null) ...[
                            const SizedBox(width: 12),
                            _buildMiniBadge(Icons.public, platform),
                          ],
                          if (!isLink && calories != null) ...[
                            const SizedBox(width: 12),
                            _buildMiniBadge(
                                Icons.local_fire_department, calories),
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              ),

              // 4. Delete Button (Top Right)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5), // Glassy background
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white70, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context) {
    final title = recipe['title'] ?? 'Untitled';
    final isLink = recipe['type'] == 'link';
    final platform = recipe['platform'];
    final calories = recipe['calories'];

    return Stack(
      children: [
        Hero(
          tag: 'recipe_thumb_${recipe['recipe_id'] ?? recipe['title']}',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              image: _getImageProvider(recipe) != null
                  ? DecorationImage(
                      image: _getImageProvider(recipe)!,
                      fit: BoxFit.cover,
                    )
                  : null,
              color: AppColors.deepCharcoal, // Fallback color
            ),
            child: _getImageProvider(recipe) == null
                ? Center(
                    child: Icon(
                      isLink ? Icons.link : Icons.restaurant_menu_rounded,
                      color: AppColors.zestyLime.withOpacity(0.5),
                      size: 48,
                    ),
                  )
                : null,
          ),
        ),
        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
        ),
        // Content
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Right: Delete Button (Small)
                  // We position this using a Stack or just use Align in the column if we want it clickable separately.
                  // But InkWell covers everything. Let's put a separate clickable delete button at the top using Stack later
                  // actually, better to keep the InkWell for the card, and position the delete button above the InkWell in a Stack.

                  // Main Text content
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isLink && platform != null)
                        Expanded(child: _buildGlassBadge(platform))
                      else if (!isLink && calories != null)
                        Expanded(child: _buildGlassBadge(calories))
                      else
                        Expanded(child: _buildGlassBadge("Recipe")),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
        // Helper Action Buttons (Top Right)
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Colors.white70, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.zestyLime),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildGlassBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.electricWhite,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  ImageProvider? _getImageProvider(Map<String, dynamic> recipe) {
    final thumbUrl = recipe['thumbnail'] ?? recipe['image'] as String?;
    if (thumbUrl == null || thumbUrl.isEmpty) return null;

    if (thumbUrl.startsWith('data:')) {
      try {
        final base64String = thumbUrl.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint("Base64 Error: $e");
        return null;
      }
    } else if (thumbUrl.startsWith('http')) {
      return NetworkImage(thumbUrl);
    }
    return null;
  }
}
