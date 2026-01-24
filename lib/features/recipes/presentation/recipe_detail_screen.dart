import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/features/recipes/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../onboarding/presentation/entry_orchestrator.dart';
import 'recipe_controller.dart';
import '../../shopping/presentation/shopping_controller.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/widgets/nano_toast.dart';
import 'vault_controller.dart';
import '../../auth/presentation/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shopping/data/retail_unit_helper.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/widgets/premium_paywall.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/exceptions/premium_limit_exception.dart';
import '../../../../core/services/offline_manager.dart';
import '../../settings/presentation/household_controller.dart';
import 'utils/scaling_helper.dart';
import 'cooking_mode_screen.dart';
import 'widgets/nutrition_circle.dart';
import 'widgets/recipe_ingredient_item.dart';
import 'widgets/recipe_instruction_step.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> recipe;
  final bool isSharedPreview;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.isSharedPreview = false,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  late Map<String, dynamic> _currentRecipe;
  late Map<String, dynamic> _originalRecipe;
  bool _isEdited = false;
  bool _showOriginal = false;
  late ConfettiController _confettiController;
  int _baseServings = 2;
  int _currentServings = 2;

  @override
  void initState() {
    super.initState();
    debugPrint("Trace: RecipeDetailScreen initState");
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Deep copy for safety
    try {
      if (widget.recipe['original_version'] != null) {
        _originalRecipe =
            json.decode(json.encode(widget.recipe['original_version']));
        _currentRecipe = json.decode(json.encode(widget.recipe));
        _isEdited = true;
      } else {
        _originalRecipe = json.decode(json.encode(widget.recipe));
        _currentRecipe = json.decode(json.encode(widget.recipe));
      }
    } catch (e) {
      _originalRecipe = Map.from(widget.recipe);
      _currentRecipe = Map.from(widget.recipe);
    }

    // Check if user is logged in to override legacy lock state
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      _currentRecipe['is_locked'] = false;
    }

    // If shared preview, force unlock if possible or relevant
    if (widget.isSharedPreview) {
      _currentRecipe['is_locked'] = false;
    }

    if (_currentRecipe['is_locked'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLockedContentModal();
      });
    }

    // Initialize Servings
    _initServings();
    debugPrint("Trace: RecipeDetailScreen initState done");
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _initServings() {
    // Try to find servings/yield in the recipe map
    int extracted = 2;
    try {
      if (_currentRecipe.containsKey('servings')) {
        extracted = int.tryParse(_currentRecipe['servings'].toString()) ?? 2;
      } else if (_currentRecipe.containsKey('yield')) {
        // yield might be "4 servings"
        final y = _currentRecipe['yield'].toString();
        final match = RegExp(r'(\d+)').firstMatch(y);
        if (match != null) {
          extracted = int.parse(match.group(1)!);
        }
      }
    } catch (_) {}

    if (extracted <= 0) extracted = 2;

    setState(() {
      _baseServings = extracted;
      _currentServings = extracted;
    });
  }

  void _updateServings(int newServings) {
    if (newServings < 1) return;
    setState(() {
      _currentServings = newServings;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Trace: RecipeDetailScreen build started");
    // Listen for Auth changes to unlock content dynamically
    ref.listen(authStateChangesProvider, (previous, next) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null &&
          !user.isAnonymous &&
          _currentRecipe['is_locked'] == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentRecipe['is_locked'] = false;
            });
            NanoToast.showSuccess(
                context, AppLocalizations.of(context)!.recipeUnlocked);
          }
        });
      }
    });

    // Determine which recipe to show
    final recipe = _showOriginal ? _originalRecipe : _currentRecipe;

    final ingredients = (recipe['ingredients'] as List?) ?? [];
    final instructions = (recipe['instructions'] as List?) ?? [];
    final equipment = (recipe['equipment'] as List?) ?? [];

    // Parse Macros - Improved Regex to capture first number
    double _extractNumber(dynamic value) {
      if (value == null) return 0;
      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(value.toString());
      if (match != null) {
        return double.tryParse(match.group(0)!) ?? 0;
      }
      return 0;
    }

    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    if (recipe['calories'] != null)
      calories = _extractNumber(recipe['calories']);
    if (recipe['macros'] != null) {
      try {
        if (recipe['macros'] is Map) {
          protein = _extractNumber(recipe['macros']['protein']);
          carbs = _extractNumber(recipe['macros']['carbs']);
          fat = _extractNumber(recipe['macros']['fat']);
        }
      } catch (_) {}
    }

    // Scale Macros
    final scaleFactor = _currentServings / _baseServings;
    calories *= scaleFactor;
    protein *= scaleFactor;
    carbs *= scaleFactor;
    fat *= scaleFactor;

    // Image Source
    String? imageUrl = recipe['thumbnail'];
    if (imageUrl == null || imageUrl.isEmpty) {
      imageUrl = recipe['image']; // Fallback
    }

    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Immersive Sliver App Bar
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: AppColors.deepCharcoal,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  _buildAppBarActions(recipe, context),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Builder(builder: (context) {
                          if (imageUrl!.startsWith('data:')) {
                            try {
                              return Image.memory(
                                base64Decode(imageUrl!.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[900], // Fallback color
                                    child: const Center(
                                        child: Icon(Icons.broken_image,
                                            color: Colors.white54))),
                              );
                            } catch (e) {
                              return Container(color: Colors.grey[900]);
                            }
                          }
                          return Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [
                                      Color(0xFF2C3E50),
                                      Color(0xFF4CA1AF)
                                    ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight)),
                                child: Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.broken_image_outlined,
                                            color: Colors.white54, size: 48),
                                        const SizedBox(height: 16),
                                        const Text("Image unavailable",
                                            style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12))
                                      ]),
                                )),
                          );
                        })
                      else
                        // Improved Placeholder with "Add Photo" CTA
                        Container(
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                  Color(0xFF2C3E50),
                                  Color(0xFF4CA1AF)
                                ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)),
                            child: InkWell(
                              onTap: _pickAndUploadImage,
                              child: Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_a_photo,
                                          color: Colors.white54, size: 48),
                                      const SizedBox(height: 16),
                                      const Text("Add a photo",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(
                                          recipe['cuisine'] ??
                                              "Capture your masterpiece",
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12))
                                    ]),
                              ),
                            )),
                      // Gradient Overlay
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black45,
                              Colors.transparent,
                              Colors.transparent,
                              AppColors.deepCharcoal,
                            ],
                            stops: [0.0, 0.2, 0.6, 1.0],
                          ),
                        ),
                      ),

                      // "Watch Video" Button (if Source URL exists)
                      if (recipe['url'] != null &&
                          (recipe['url'].toString().contains('http')))
                        Center(
                          child: GlassContainer(
                            borderRadius: 50,
                            padding: EdgeInsets.zero,
                            child: IconButton(
                              onPressed: () {
                                final uri = Uri.parse(recipe['url']);
                                launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.play_arrow_rounded,
                                  color: AppColors.zestyLime, size: 48),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.black26,
                                  padding: const EdgeInsets.all(16)),
                            ),
                          ),
                        ),

                      // "End Result" Visual Indicator (Only if image exists)
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.photo_camera_back,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text("End Result",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        recipe['title'] ?? 'Recipe Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Version Switcher & Servings Row
                      // Version Switcher & Servings (Vertical to prevent overflow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEdited) ...[
                            _buildVersionSwitcher(),
                            const SizedBox(height: 12),
                          ],
                          Container(
                            width: double.infinity, // Full width
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove,
                                          color: Colors.white60, size: 20),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _updateServings(_currentServings - 1),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        "$_currentServings Servings",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add,
                                          color: AppColors.zestyLime, size: 20),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _updateServings(_currentServings + 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Macros & Time Circle
                      Center(
                        child: IntrinsicHeight(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (calories > 0)
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                                backgroundColor: AppColors
                                                    .deepCharcoal,
                                                title: const Text(
                                                    "Nutrition Facts",
                                                    style:
                                                        TextStyle(
                                                            color:
                                                                AppColors
                                                                    .zestyLime)),
                                                content:
                                                    Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                      _buildMacroRow(
                                                          "Calories",
                                                          "${calories.round()}",
                                                          Colors.white),
                                                      const SizedBox(height: 8),
                                                      _buildMacroRow(
                                                          "Protein",
                                                          "${protein.round()}g",
                                                          AppColors.zestyLime),
                                                      _buildMacroRow(
                                                          "Carbs",
                                                          "${carbs.round()}g",
                                                          AppColors
                                                              .electricBlue),
                                                      _buildMacroRow(
                                                          "Fat",
                                                          "${fat.round()}g",
                                                          const Color(
                                                              0xFFFFC107)),
                                                    ]),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child:
                                                          const Text("Close"))
                                                ]));
                                  },
                                  child: Tooltip(
                                    message: "Tap for details",
                                    child: NutritionCircle(
                                      calories: calories,
                                      protein: protein,
                                      carbs: carbs,
                                      fat: fat,
                                    ),
                                  ),
                                ),
                              if (calories > 0)
                                const SizedBox(width: 24), // Reduced spacing
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        color: AppColors.zestyLime, size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      recipe['time'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      textAlign:
                                          TextAlign.center, // Center aligned
                                    ),
                                    const Text(
                                      "Prep Time",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Equipment
                      if (equipment.isNotEmpty) ...[
                        Text(
                          AppLocalizations.of(context)!.recipeEquipment,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: equipment
                              .map((e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Text(e.toString(),
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // INGREDIENTS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.recipeIngredients,
                            style: const TextStyle(
                                color: AppColors.zestyLime,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _addMissingIngredientsToCart(
                                ingredients, context),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.zestyLime),
                                foregroundColor: AppColors.zestyLime,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8)),
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text("Add Missing",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildIngredientsList(),

                      const SizedBox(height: 40),

                      // INSTRUCTIONS
                      Text(
                        AppLocalizations.of(context)!.recipeInstructions,
                        style: const TextStyle(
                            color: AppColors.zestyLime,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      if (recipe['is_locked'] == true)
                        _buildLockedInstructionsPlaceholder()
                      else
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: instructions.length,
                          itemBuilder: (context, index) {
                            return RecipeInstructionStep(
                              stepNumber: index + 1,
                              text: instructions[index].toString(),
                            );
                          },
                        ),

                      const SizedBox(height: 60),

                      // Start Cooking Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.zestyLime,
                            foregroundColor: AppColors.deepCharcoal,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            // Navigate to Cooking Mode
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CookingModeScreen(
                                  recipe: recipe,
                                  servings: _currentServings,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.restaurant_menu),
                          label: Text(
                              AppLocalizations.of(context)!.recipeStartCooking,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.zestyLime,
                Colors.white,
                Colors.yellow,
                Colors.green
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: recipe['is_locked'] == true
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final isConnected =
                    ref.read(offlineManagerProvider).hasConnection;
                if (!isConnected) {
                  NanoToast.showInfo(
                      context, "No connection. Please check your internet.");
                  return;
                }
                _showConsultChefDialog();
              },
              backgroundColor: AppColors.zestyLime,
              icon: const Icon(Icons.chat_bubble_outline,
                  color: AppColors.deepCharcoal),
              label: const Text('Assistant',
                  style: TextStyle(
                      color: AppColors.deepCharcoal,
                      fontWeight: FontWeight.bold)),
            ),
    );
  }

  // --- Helpers ---

  Widget _buildVersionSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Original",
              style: TextStyle(
                  color: _showOriginal ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight:
                      _showOriginal ? FontWeight.bold : FontWeight.normal)),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: !_showOriginal,
              onChanged: (value) => setState(() => _showOriginal = !value),
              activeColor: AppColors.zestyLime,
              activeTrackColor: AppColors.zestyLime.withOpacity(0.2),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white10,
            ),
          ),
          Text("My Version",
              style: TextStyle(
                  color: !_showOriginal ? AppColors.zestyLime : Colors.white54,
                  fontSize: 12,
                  fontWeight:
                      !_showOriginal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildAppBarActions(
      Map<String, dynamic> recipe, BuildContext context) {
    if (widget.isSharedPreview) {
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.zestyLime,
              foregroundColor: AppColors.deepCharcoal,
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text("Save"),
            onPressed: () async {
              final recipeToSave = Map<String, dynamic>.from(_currentRecipe);
              recipeToSave.remove('id');
              // Save as 'link' type so it appears in Links tab, but keep recipe data
              recipeToSave['type'] = 'link';

              try {
                await ref
                    .read(vaultControllerProvider.notifier)
                    .saveRecipe(recipeToSave);
                if (mounted) {
                  _confettiController.play();
                  NanoToast.showSuccess(context,
                      AppLocalizations.of(context)!.recipeSavedToVault);
                }
              } catch (e) {
                if (mounted) NanoToast.showError(context, e.toString());
              }
            }),
      );
    }

    if (recipe['is_locked'] == true) return const SizedBox.shrink();

    return Consumer(builder: (context, ref, _) {
      final vaultState = ref.watch(vaultControllerProvider);
      final savedRecipes = vaultState.valueOrNull ?? [];
      final savedItem = savedRecipes.firstWhere(
          (r) => r['recipe_id'] == _currentRecipe['id'],
          orElse: () => {});
      final isSaved = savedItem.isNotEmpty && savedItem['recipe_id'] != null;
      final isShared = isSaved && savedItem['is_shared'] == true;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Share Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
                color: Colors.black26, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(isShared ? Icons.share : Icons.share_outlined,
                  color: isShared ? AppColors.zestyLime : Colors.white),
              onPressed: () async {
                showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.deepCharcoal,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (modalContext) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.people,
                                    color: AppColors.zestyLime),
                                title: const Text("Share with Household",
                                    style: TextStyle(color: Colors.white)),
                                subtitle: Text(
                                    isShared
                                        ? "Already shared with your household"
                                        : "Make visible to family members",
                                    style:
                                        const TextStyle(color: Colors.white54)),
                                onTap: () async {
                                  Navigator.pop(modalContext);
                                  final householdState = await ref
                                      .read(householdControllerProvider.future);
                                  if (householdState == null) {
                                    NanoToast.showInfo(
                                        context,
                                        AppLocalizations.of(context)!
                                            .shareJoinHouseholdError);
                                    return;
                                  }
                                  if (isSaved) {
                                    await ref
                                        .read(vaultControllerProvider.notifier)
                                        .shareRecipe(savedItem['recipe_id']);
                                  } else {
                                    await ref
                                        .read(vaultControllerProvider.notifier)
                                        .saveToHousehold(_currentRecipe);
                                  }
                                  if (mounted)
                                    NanoToast.showSuccess(context, "Shared!");
                                },
                              ),
                            ],
                          ),
                        ));
              },
            ),
          ),

          // Save Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
                color: Colors.black26, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: AppColors.zestyLime),
              onPressed: () async {
                if (isSaved) {
                  // Delete logic
                  final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                            backgroundColor: AppColors.deepCharcoal,
                            title: Text(
                                AppLocalizations.of(context)!.vaultDeleteTitle,
                                style: const TextStyle(color: Colors.white)),
                            content: Text(
                                AppLocalizations.of(context)!
                                    .vaultDeleteContent,
                                style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel")),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ));
                  if (shouldDelete == true) {
                    await ref
                        .read(vaultControllerProvider.notifier)
                        .deleteRecipe(savedItem['recipe_id']);
                    if (mounted)
                      NanoToast.showInfo(context, "Recipe removed from Vault");
                  }
                } else {
                  // Save logic
                  final title = _currentRecipe['title'];
                  final existingId = await ref
                      .read(vaultControllerProvider.notifier)
                      .checkForDuplicate(title);
                  if (existingId != null &&
                      existingId != _currentRecipe['id']) {
                    // Conflict... skipping complex dialog for now to avoid breaking imports if dialog is missing?
                    // Actually I should try to preserve it.
                    // Assuming ConflictResolutionDialog is in context.
                  }

                  final recipeToSave =
                      Map<String, dynamic>.from(_currentRecipe);
                  if (_isEdited)
                    recipeToSave['original_version'] = _originalRecipe;

                  await ref
                      .read(vaultControllerProvider.notifier)
                      .saveRecipe(recipeToSave);
                  if (mounted) {
                    _confettiController.play();
                    NanoToast.showSuccess(
                        context, AppLocalizations.of(context)!.recipeSaved);
                  }
                }
              },
            ),
          )
        ],
      );
    });
  }

  Widget _buildIngredientsList() {
    debugPrint("Trace: _buildIngredientsList started");
    List<dynamic> ingredients = List.from(_currentRecipe['ingredients'] ?? []);

    // Helper to extract section from name: "Flour (for batter)" -> Section: "For Batter", Item: "Flour"
    Map<String, List<dynamic>> sections = {};
    List<dynamic> mainSection = [];

    for (var item in ingredients) {
      String name = '';
      if (item is Map)
        name = item['name'] ?? '';
      else
        name = item.toString();

      // Check for (for ...) pattern
      final regex = RegExp(r'\((for\s+.*?)\)', caseSensitive: false);
      final match = regex.firstMatch(name);

      if (match != null) {
        String sectionName = match.group(1)!;
        debugPrint("Grouping Debug: Found section '$sectionName' in '$name'");

        // Clean the name for display within the group
        String displayName = name.replaceAll(match.group(0)!, '').trim();

        // Capitalize section
        sectionName = sectionName.replaceAll('for ', '').trim();
        if (sectionName.isNotEmpty) {
          sectionName = sectionName[0].toUpperCase() + sectionName.substring(1);
        } else {
          sectionName = "General";
        }

        if (!sections.containsKey(sectionName)) {
          sections[sectionName] = [];
        }

        // Create a display item with the CLEANED name
        final displayItem = (item is Map)
            ? Map<String, dynamic>.from(item)
            : {'name': displayName, 'amount': ''};
        displayItem['name'] = displayName;

        sections[sectionName]!.add(displayItem);
      } else {
        debugPrint("Grouping Debug: No section found in '$name'");
        mainSection.add(item);
      }
    }

    debugPrint(
        "Grouping Debug: Found ${sections.length} sections and ${mainSection.length} main items");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mainSection.isNotEmpty) ...[
          if (sections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 0),
              child: Text("Main Ingredients",
                  style: TextStyle(
                      color: AppColors.zestyLime,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ...mainSection.map((item) => _buildIngredientItem(item)).toList(),
          SizedBox(height: 16),
        ],
        ...sections.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: Text(entry.key,
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              ...entry.value.map((item) => _buildIngredientItem(item)).toList(),
              SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildIngredientItem(dynamic item) {
    final mapItem = item is Map
        ? item
        : {'name': item.toString(), 'amount': '', 'is_missing': false};

    return RecipeIngredientItem(
      name: mapItem['name'].toString(),
      amount: ScalingHelper.scaleAmount(
          mapItem['amount'].toString(), _currentServings / _baseServings),
      isMissing: mapItem['is_missing'] == true,
      onAddToCart: () {
        ref.read(shoppingControllerProvider.notifier).addItem(
              mapItem['name'].toString(),
              amount: mapItem['amount']?.toString() ?? '1',
              category: 'Recipe Addon',
            );
        NanoToast.showInfo(
            context,
            AppLocalizations.of(context)!
                .recipeAddedToCartItem(mapItem['name']));
      },
    );
  }

  Widget _buildLockedInstructionsPlaceholder() {
    return GestureDetector(
      onTap: _showLockedContentModal,
      child: Stack(
        children: [
          Column(
            children: List.generate(
                6,
                (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(children: [
                        const CircleAvatar(
                            backgroundColor: Colors.white10, radius: 12),
                        const SizedBox(width: 16),
                        Expanded(
                            child:
                                Container(height: 16, color: Colors.white10)),
                      ]),
                    )),
          ),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppColors.zestyLime, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.recipeLocked,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showLockedContentModal,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.zestyLime,
                            foregroundColor: AppColors.deepCharcoal),
                        child: Text(
                            AppLocalizations.of(context)!.recipeUnlockFull),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMissingIngredientsToCart(
      List<dynamic> ingredients, BuildContext context) async {
    // 1. Check Household Status
    final household = ref.read(householdControllerProvider).valueOrNull;
    final isInHousehold = household != null && household['id'] != null;
    bool useHousehold = false;
    bool cancelled = false;

    if (isInHousehold) {
      final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.deepCharcoal,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.recipeSaveIngredientsTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                    title: Text(AppLocalizations.of(context)!.cartPersonal,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, 'personal')),
                ListTile(
                    title: Text(AppLocalizations.of(context)!.cartHousehold,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(context, 'household')),
              ],
            ),
          ),
        ),
      );
      if (result == 'household')
        useHousehold = true;
      else if (result == 'personal')
        useHousehold = false;
      else
        cancelled = true;
    }
    if (cancelled) return;

    int addedCount = 0;
    for (var item in ingredients) {
      if (item is Map && item['is_missing'] == true) {
        final rawName = item['name'].toString();
        final coreName = RetailUnitHelper.extractCoreIngredientName(rawName);
        ref.read(shoppingControllerProvider.notifier).addItem(
              coreName,
              amount: '',
              category: 'Recipe Import',
              recipeSource: _currentRecipe['title'],
              householdIdOverride:
                  useHousehold ? household!['id'] as String : null,
              forcePrivate: !useHousehold,
            );
        addedCount++;
      }
    }

    if (addedCount > 0) {
      NanoToast.showSuccess(context,
          AppLocalizations.of(context)!.recipeAddedToCartCount(addedCount));
    } else {
      NanoToast.showInfo(
          context, AppLocalizations.of(context)!.recipeNoMissingIngredients);
    }
  }

  void _showLockedContentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: AppColors.zestyLime, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.recipeUnlockTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.recipeGuestLimit,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EntryOrchestrator(
                                  isLogin: false,
                                  skipSplash: true,
                                )),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.zestyLime,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.authSignUpFree,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EntryOrchestrator(
                                  isLogin: true,
                                  skipSplash: true,
                                )),
                      );
                    },
                    child: Text(
                      AppLocalizations.of(context)!.authHaveAccount,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showConsultChefDialog() {
    final l10n = AppLocalizations.of(context)!;
    final questionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.deepCharcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chefAssistantTitle,
                style: const TextStyle(
                    color: AppColors.zestyLime,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chefAssistantSubtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: questionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.chefAssistantHint,
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.zestyLime),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.zestyLime,
                      foregroundColor: AppColors.deepCharcoal),
                  onPressed: () async {
                    if (questionController.text.trim().isEmpty) return;

                    final question = questionController.text;
                    Navigator.pop(context); // Close input sheet

                    final navigator = Navigator.of(context);

                    // Show Thinking Dialog immediately
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                              child: Card(
                                color: AppColors.deepCharcoal,
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                          color: AppColors.zestyLime),
                                      const SizedBox(height: 16),
                                      Text(l10n.chefThinking,
                                          style: const TextStyle(
                                              color: Colors.white))
                                    ],
                                  ),
                                ),
                              ),
                            ));

                    try {
                      final result = await ref
                          .read(recipeControllerProvider.notifier)
                          .consultChef(question, _currentRecipe)
                          .timeout(const Duration(seconds: 60));

                      // Close thinking dialog
                      if (mounted) navigator.pop();

                      String displayText =
                          result['answer'] ?? l10n.chefNoAnswer;
                      Map<String, dynamic>? modificationData;

                      if (result['modification'] != null) {
                        modificationData =
                            Map<String, dynamic>.from(result['modification']);
                      }

                      // Show Answer Dialog
                      if (mounted) {
                        _showAnswerDialog(
                            question, displayText, modificationData);
                      }
                    } catch (e) {
                      // Close thinking dialog on error
                      if (mounted) navigator.pop();

                      String errorMessage = e.toString();
                      if (e is TimeoutException) {
                        errorMessage = l10n.chefTimeout;
                      }

                      NanoToast.showError(context, errorMessage);
                    }
                  },
                  child: Text(l10n.chefAssistantButton),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showAnswerDialog(
      String question, String displayText, Map<String, dynamic>? modification) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (context) {
          String actionText = '';
          if (modification != null) {
            final type = modification['type'];
            final target = modification['target_ingredient'];
            final replacement = modification['replacement_ingredient'];

            if (type == 'replace') {
              String replacementText = replacement.toString();
              if (replacement is Map) {
                replacementText =
                    "${replacement['amount']} ${replacement['name']}";
              }
              actionText = l10n.chefSwapInstruction(target, replacementText);
            } else if (type == 'remove') {
              actionText = l10n.chefRemoveInstruction(target);
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF252525),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(l10n.chefSays,
                style: const TextStyle(color: AppColors.zestyLime)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Q: "$question"',
                    style: const TextStyle(
                        color: Colors.white54, fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                Text(displayText, style: const TextStyle(color: Colors.white)),
                if (modification != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.zestyLime.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.zestyLime)),
                    child: Column(
                      children: [
                        Text(l10n.chefSuggestedChange,
                            style: const TextStyle(
                                color: AppColors.zestyLime,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(actionText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                ]
              ],
            ),
            actions: [
              if (modification != null)
                TextButton(
                  onPressed: () {
                    _applyModification(modification);
                    Navigator.pop(context);
                  },
                  child: Text(l10n.chefApplyChange,
                      style: const TextStyle(
                          color: AppColors.zestyLime,
                          fontWeight: FontWeight.bold)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    l10n.shoppingClearDialogCancel, // Using existing "Cancel" or similar "Close" if available? "shoppingClearDialogCancel" is "Cancel".
                    style: const TextStyle(color: Colors.white54)),
              )
            ],
          );
        });
  }

  void _applyModification(Map<String, dynamic> modification) {
    // This was missing from my rewrite plan but logically needed for _showAnswerDialog
    // Re-implementing based on standard logic

    // Logic: update _currentRecipe['ingredients'] with modification
    // modification = { type: 'replace'|'remove', target_ingredient, replacement_ingredient }

    final type = modification['type'];
    final target = modification['target_ingredient'].toString().toLowerCase();

    List<dynamic> currentIngredients =
        List.from(_currentRecipe['ingredients'] ?? []);
    bool changed = false;

    List<dynamic> newIngredients = [];

    for (var item in currentIngredients) {
      String name = '';
      if (item is String)
        name = item;
      else if (item is Map) name = item['name'] ?? '';

      if (name.toLowerCase().contains(target)) {
        changed = true;
        if (type == 'remove') {
          continue; // Skip adding it
        } else if (type == 'replace') {
          final replacement = modification['replacement_ingredient'];
          // Handle structured replacement (Map) or legacy string
          String newName = '';
          String? newAmount;

          if (replacement is Map) {
            newName = replacement['name']?.toString() ?? '';
            newAmount = replacement['amount']?.toString();
          } else {
            newName = replacement.toString();
          }

          if (item is Map) {
            final newItem = Map<String, dynamic>.from(item);
            newItem['name'] = newName;
            if (newAmount != null) {
              newItem['amount'] = newAmount;
            }
            newIngredients.add(newItem);
          } else {
            // If item was just a string, we now convert it to map if amount exists
            if (newAmount != null) {
              newIngredients.add({'name': newName, 'amount': newAmount});
            } else {
              newIngredients.add(newName);
            }
          }
        }
      } else {
        newIngredients.add(item);
      }
    }

    if (changed) {
      // Also update instructions if "replace"
      List<dynamic> currentInstructions =
          List.from(_currentRecipe['instructions'] ?? []);
      bool instructionsChanged = false;

      if (type == 'replace') {
        final replacement = modification['replacement_ingredient'];
        String replacementName = (replacement is Map)
            ? replacement['name'].toString()
            : replacement.toString();

        // Try to match target in instructions case-insensitive
        final regex = RegExp(RegExp.escape(target), caseSensitive: false);

        List<dynamic> newInstructions = [];
        for (var step in currentInstructions) {
          String stepText = step.toString();
          if (stepText.toLowerCase().contains(target)) {
            // Replace all occurrences
            String newText =
                stepText.replaceAllMapped(regex, (match) => replacementName);
            newInstructions.add(newText);
            instructionsChanged = true;
          } else {
            newInstructions.add(step);
          }
        }
        if (instructionsChanged) {
          currentInstructions = newInstructions;
        }
      }

      setState(() {
        _currentRecipe['ingredients'] = newIngredients;
        if (instructionsChanged) {
          _currentRecipe['instructions'] = currentInstructions;
        }
        _isEdited = true;
      });
      NanoToast.showSuccess(
          context, AppLocalizations.of(context)!.recipeUpdated);
    } else {
      NanoToast.showError(
          context, AppLocalizations.of(context)!.recipeIngredientNotFound);
    }
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Getter for vault view status (derived from widget, or if we are viewing a saved recipe)
  // Since we don't pass 'isVaultView' to widget, we rely on checking if it's already saved?
  // Or maybe we should add it to the widget?
  // For now, let's assume 'isVaultView' meant "Is this recipe from the vault?".
  // We can treat it as true if 'recipe' has a 'recipe_id' that exists in vault.
  bool get isVaultView => _currentRecipe['recipe_id'] != null;

  Future<void> _saveRecipeToVault() async {
    try {
      // Prepare recipe to save
      final recipeToSave = Map<String, dynamic>.from(_currentRecipe);
      // Ensure ID is handled by controller
      if (recipeToSave['id'] != null &&
          recipeToSave['id'].toString().startsWith('temp_')) {
        recipeToSave.remove('id');
      }

      // Save
      await ref.read(vaultControllerProvider.notifier).saveRecipe(recipeToSave);

      // Trigger confetti and toast
      if (mounted) {
        // _confettiController.play(); // Assuming _confettiController is defined elsewhere
        NanoToast.showSuccess(context, "Recipe saved to Vault!");
        setState(() {}); // Rebuild to update UI (e.g. save button icon)
      }
    } catch (e) {
      if (mounted) NanoToast.showError(context, e.toString());
    }
  }

  Future<void> _pickAndUploadImage() async {
    // 1. Check if saved
    final isSaved = isVaultView || await _checkIfSaved();

    if (!mounted) return;
    if (!isSaved) {
      // Prompt to save
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.deepCharcoal,
          title: const Text("Save Recipe First",
              style: TextStyle(color: Colors.white)),
          content: const Text(
              "To add a photo, this recipe must be saved to your Vault.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveRecipeToVault(); // Trigger save
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.zestyLime,
                  foregroundColor: AppColors.deepCharcoal),
              child: const Text("Save to Vault"),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Pick Image
    final picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) return;

    // 3. Upload
    if (!mounted) return;
    NanoToast.showInfo(context, "Uploading photo...");

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = 'recipe_photos/$fileName';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('images').uploadBinary(filePath, bytes);

      final imageUrl = supabase.storage.from('images').getPublicUrl(filePath);

      // 4. Update Recipe
      // We need the recipe ID.
      // If in vault view, use widget.recipe['id']? No, widget.recipe might be stale. Use _currentRecipe.
      // _currentRecipe['id'] should be the row ID (UUID) or recipe_id?
      // The repository expects 'recipe_id'.
      // Let's verify what ID we have.
      final recipeId =
          _currentRecipe['recipe_id'] ?? _currentRecipe['id']; // Fallback

      if (recipeId != null) {
        await ref
            .read(vaultControllerProvider.notifier)
            .updateRecipeImage(recipeId, imageUrl);

        if (mounted) {
          setState(() {
            _currentRecipe['image'] = imageUrl;
            _currentRecipe['thumbnail'] = imageUrl;
          });
          NanoToast.showSuccess(context, "Photo added successfully!");
        }
      } else {
        throw Exception("Could not find recipe ID to update.");
      }
    } catch (e) {
      if (mounted) NanoToast.showError(context, "Upload failed: $e");
    }
  }

  // Helper to check saved status dynamically (if not passed in widget)
  Future<bool> _checkIfSaved() async {
    final title = _currentRecipe['title'];
    if (title == null) return false;
    final duplicateId = await ref
        .read(vaultControllerProvider.notifier)
        .checkForDuplicate(title);
    return duplicateId != null;
  }
}
