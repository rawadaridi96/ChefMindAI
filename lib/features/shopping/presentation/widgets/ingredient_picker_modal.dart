import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/shopping_ingredients.dart';

/// A modal that displays a visual grid of ingredients for the user to select.
///
/// Features:
/// - Category tabs at the top
/// - Search bar to filter ingredients
/// - Grid of ingredients with images
/// - "Add Custom Item" option for manual text entry
class IngredientPickerModal extends StatefulWidget {
  /// Called when user selects an ingredient from the grid
  final Function(ShoppingIngredient ingredient) onIngredientSelected;

  /// Called when user wants to add a custom item (not in list)
  final VoidCallback onCustomItemTap;

  const IngredientPickerModal({
    super.key,
    required this.onIngredientSelected,
    required this.onCustomItemTap,
  });

  @override
  State<IngredientPickerModal> createState() => _IngredientPickerModalState();
}

class _IngredientPickerModalState extends State<IngredientPickerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: IngredientCategory.all.length,
      vsync: this,
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ShoppingIngredient> _getFilteredIngredients(String category) {
    final categoryIngredients =
        ShoppingIngredientRepository.getByCategory(category);

    if (_searchQuery.isEmpty) {
      return categoryIngredients;
    }

    return categoryIngredients
        .where((i) => i.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<ShoppingIngredient> _getAllFilteredIngredients() {
    if (_searchQuery.isEmpty) {
      return [];
    }
    return ShoppingIngredientRepository.search(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Add Ingredient",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search ingredients...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon:
                                const Icon(Icons.clear, color: Colors.white54),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // Custom Item Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCustomItemTap();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Add Custom Item"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.zestyLime,
                      side: const BorderSide(color: AppColors.zestyLime),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Category Tabs (hidden when searching)
          if (!isSearching)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.zestyLime,
              labelColor: AppColors.zestyLime,
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs:
                  IngredientCategory.all.map((cat) => Tab(text: cat)).toList(),
            ),

          // Ingredient Grid
          Expanded(
            child: isSearching
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: IngredientCategory.all.map((category) {
                      return _buildIngredientGrid(
                        _getFilteredIngredients(category),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _getAllFilteredIngredients();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              "No results for \"$_searchQuery\"",
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onCustomItemTap();
              },
              icon: const Icon(Icons.add),
              label: Text("Add \"$_searchQuery\""),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zestyLime,
                foregroundColor: AppColors.deepCharcoal,
              ),
            ),
          ],
        ),
      );
    }

    return _buildIngredientGrid(results);
  }

  Widget _buildIngredientGrid(List<ShoppingIngredient> ingredients) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = ingredients[index];
        return _buildIngredientTile(ingredient);
      },
    );
  }

  Widget _buildIngredientTile(ShoppingIngredient ingredient) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onIngredientSelected(ingredient);
      },
      child: Column(
        children: [
          // Icon Container - SVG or Emoji
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: ingredient.preferImage
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: ingredient.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white24,
                      ),
                      errorWidget: (context, url, error) => Text(
                        ingredient.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  )
                : ingredient.hasSvgIcon
                    ? ClipOval(
                        child: Image.asset(
                          ingredient.svgPath!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(
                                'Icon load error for ${ingredient.name}: $error');
                            return Text(
                              ingredient.emoji,
                              style: const TextStyle(fontSize: 36),
                            );
                          },
                        ),
                      )
                    : Text(
                        ingredient.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
          ),
          const SizedBox(height: 6),

          // Name
          Text(
            ingredient.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
