import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/fun_loading_tips.dart';
import 'package:chefmind_ai/core/widgets/brand_logo.dart';
import 'package:chefmind_ai/core/widgets/chefmind_watermark.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/widgets/nano_toast.dart';

import 'recipe_controller.dart';
import 'vault_controller.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _showVaultLinks = false;

  // Vault Search State
  final TextEditingController _vaultSearchController = TextEditingController();
  String _vaultSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _vaultSearchController.addListener(() {
      setState(() {
        _vaultSearchQuery = _vaultSearchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vaultSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch state here to use isLoading in AppBar
    final state = ref.watch(recipeControllerProvider);

    ref.listen(recipeControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        NanoToast.showError(
            context, next.error.toString().replaceAll('Exception: ', ''));
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: BrandLogo(
          fontSize: 24,
          isBusy: state.isLoading,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.zestyLime,
          labelColor: AppColors.zestyLime,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Current Results'),
            Tab(text: 'The Vault'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Premium Watermark
          const Positioned(
            left: -40,
            top: 100,
            bottom: 100,
            child: ChefMindWatermark(),
          ),
          // Content
          TabBarView(
            controller: _tabController,
            children: [
              _buildResults(),
              _buildVault(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final state = ref.watch(recipeControllerProvider);

    // Explicitly check for loading state to ensure the spinner is shown
    // even if we have previous data (e.g. valid reload).
    if (state.isLoading) {
      return const FunLoadingTips();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        // Results
        Expanded(
          child: state.when(
            data: (recipes) {
              if (recipes.isEmpty) {
                return const Center(
                    child: Text('Generate some magic from Home!',
                        style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  final ingredients = (recipe['ingredients'] as List?) ?? [];

                  // Calculate missing count
                  int missingCount = 0;
                  int totalIngredients = ingredients.length;

                  for (var i in ingredients) {
                    if (i is Map && i['is_missing'] == true) {
                      missingCount++;
                    }
                  }

                  int haveCount = totalIngredients - missingCount;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to Detail Screen
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    RecipeDetailScreen(recipe: recipe)));
                      },
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(recipe['title'] ?? 'Untitled',
                                      style: const TextStyle(
                                          color: AppColors.zestyLime,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: missingCount == 0
                                          ? AppColors.zestyLime.withOpacity(0.2)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: missingCount == 0
                                              ? AppColors.zestyLime
                                              : Colors.white24)),
                                  child: Text(
                                    missingCount == 0
                                        ? 'Available!'
                                        : '$haveCount/$totalIngredients Have',
                                    style: TextStyle(
                                        color: missingCount == 0
                                            ? AppColors.zestyLime
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(recipe['description'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),

                            const SizedBox(height: 16),

                            // Macro Summary Row
                            if (recipe['macros'] != null)
                              Row(
                                children: [
                                  _buildMacroBadge("PROTEIN",
                                      recipe['macros']['protein'] ?? '?g'),
                                  const SizedBox(width: 8),
                                  _buildMacroBadge("CARBS",
                                      recipe['macros']['carbs'] ?? '?g'),
                                  const SizedBox(width: 8),
                                  _buildMacroBadge(
                                      "FAT", recipe['macros']['fat'] ?? '?g'),
                                ],
                              ),

                            const SizedBox(height: 12),
                            const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "Tap for details & instructions >",
                                  style: TextStyle(
                                      color: Colors.white30,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic),
                                ))
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            // On error, we just show the prompt again (toast handles the message)
            error: (_, __) => const Center(
                child: Text('Generate some magic!',
                    style: TextStyle(color: Colors.white54))),
            loading: () => const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildVault() {
    final vaultState = ref.watch(vaultControllerProvider);

    return Column(
      children: [
        const SizedBox(height: 16),

        // Vault Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.zestyLime, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _vaultSearchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search stored recipes...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                if (_vaultSearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _vaultSearchController.clear();
                      FocusScope.of(context).unfocus();
                    },
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Vault Filter Toggles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassContainer(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showVaultLinks = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showVaultLinks
                            ? AppColors.zestyLime
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book,
                              size: 18,
                              color: !_showVaultLinks
                                  ? AppColors.deepCharcoal
                                  : Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            "Recipes",
                            style: TextStyle(
                              color: !_showVaultLinks
                                  ? AppColors.deepCharcoal
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showVaultLinks = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showVaultLinks
                            ? AppColors.zestyLime
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link,
                              size: 18,
                              color: _showVaultLinks
                                  ? AppColors.deepCharcoal
                                  : Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            "Links",
                            style: TextStyle(
                              color: _showVaultLinks
                                  ? AppColors.deepCharcoal
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 5),

        Expanded(
          child: RefreshIndicator(
            color: AppColors.zestyLime,
            backgroundColor: AppColors.deepCharcoal,
            onRefresh: () async {
              ref.invalidate(vaultControllerProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: vaultState.when(
              data: (allRecipes) {
                final recipes = allRecipes.where((r) {
                  final json = r['recipe_json'] ?? {};
                  final isLink = json['type'] == 'link';

                  // Filter by Type
                  if (_showVaultLinks && !isLink) return false;
                  if (!_showVaultLinks && isLink) return false;

                  // Filter by Search Query
                  if (_vaultSearchQuery.isNotEmpty) {
                    final title =
                        (json['title'] ?? '').toString().toLowerCase();
                    final platform =
                        (json['platform'] ?? '').toString().toLowerCase();

                    if (!title.contains(_vaultSearchQuery) &&
                        !platform.contains(_vaultSearchQuery)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (recipes.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                            child: Text(
                                _showVaultLinks
                                    ? 'No saved links yet.'
                                    : 'No saved recipes yet.',
                                style: const TextStyle(color: Colors.white54))),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final output = recipes[index];
                    final recipe = output['recipe_json'] ?? output;
                    final isLink = recipe['type'] == 'link';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Slidable(
                          key: Key(output['recipe_id']?.toString() ??
                              UniqueKey().toString()),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.25,
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  _confirmDelete(output['recipe_id']);
                                },
                                backgroundColor: AppColors.errorRed,
                                foregroundColor: Colors.white,
                                icon: Icons.delete_outline,
                                label: 'Delete',
                              ),
                            ],
                          ),
                          child: GlassContainer(
                            borderRadius: 0,
                            child: InkWell(
                              onTap: () {
                                if (isLink) {
                                  final urlText = recipe['url'];
                                  if (urlText != null) {
                                    final uri = Uri.parse(urlText);
                                    launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                } else {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => RecipeDetailScreen(
                                              recipe: recipe)));
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.zestyLime
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.zestyLime
                                                .withOpacity(0.3)),
                                      ),
                                      child: Icon(
                                        isLink
                                            ? Icons.link
                                            : Icons.restaurant_menu_rounded,
                                        color: AppColors.zestyLime,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recipe['title'] ?? 'Untitled',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today,
                                                  size: 12,
                                                  color: Colors.white38),
                                              const SizedBox(width: 4),
                                              Text(
                                                output['created_at']
                                                        ?.toString()
                                                        .split('T')[0] ??
                                                    'Recently',
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12),
                                              ),
                                              if (isLink &&
                                                  recipe['platform'] !=
                                                      null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                    width: 3,
                                                    height: 3,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color:
                                                                Colors.white38,
                                                            shape: BoxShape
                                                                .circle)),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "via ${recipe['platform']}",
                                                  style: const TextStyle(
                                                      color:
                                                          AppColors.zestyLime,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                              if (!isLink &&
                                                  recipe['calories'] !=
                                                      null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                    width: 3,
                                                    height: 3,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color:
                                                                Colors.white38,
                                                            shape: BoxShape
                                                                .circle)),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    recipe['calories'] ?? '',
                                                    style: const TextStyle(
                                                        color:
                                                            AppColors.zestyLime,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.play_circle_fill,
                                        color: Colors.white24, size: 28),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (e, s) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.errorRed, size: 48),
                          const SizedBox(height: 16),
                          const Text("Oops! Couldn't load Vault.",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(e.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                ref.refresh(vaultControllerProvider),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.zestyLime,
                                foregroundColor: AppColors.deepCharcoal),
                            child: const Text("Retry"),
                          )
                        ],
                      ),
                    )),
                  ),
                ),
              ),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.zestyLime)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.electricWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(dynamic id) async {
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title:
            const Text("Delete Recipe?", style: TextStyle(color: Colors.white)),
        content: const Text(
            "Are you sure you want to remove this from your Vault?",
            style: TextStyle(color: Colors.white70)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete",
                style: TextStyle(
                    color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(vaultControllerProvider.notifier).deleteRecipe(id);
      if (mounted) {
        NanoToast.showInfo(context, "Item removed from Vault");
      }
    }
  }
}
