import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/network_error_view.dart';
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
import '../../../../core/utils/emoji_helper.dart';
import '../../pantry/presentation/pantry_controller.dart';

import 'widgets/recipe_instruction_step.dart';
import '../../../../core/utils/string_matching_helper.dart';

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
  final Set<String> _checkedIngredients = {}; // Track checked ingredients
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
        _originalRecipe = _deepCopy(widget.recipe['original_version']);
        _currentRecipe = _deepCopy(widget.recipe);
        _isEdited = true;
      } else {
        _originalRecipe = _deepCopy(widget.recipe);
        _currentRecipe = _deepCopy(widget.recipe);
      }
    } catch (e) {
      // Fallback
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

    // Auto-check ingredients from Pantry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPantryItems();
    });

    debugPrint("Trace: RecipeDetailScreen initState done");
  }

  void _checkPantryItems() {
    final pantryItems = ref.read(pantryControllerProvider).valueOrNull ?? [];
    if (pantryItems.isEmpty) return;

    final recipeIngredients = _currentRecipe['ingredients'];
    if (recipeIngredients is! List) return;

    final Set<String> newChecks = {};

    // Get Pantry Names
    final pantryNames = pantryItems.map((e) => e['name'].toString()).toList();

    for (var item in recipeIngredients) {
      String name = '';
      if (item is Map) {
        name = item['name'].toString();
      } else {
        name = item.toString();
      }

      // Use Shared Helper
      if (StringMatchingHelper.hasMatch(name, pantryNames)) {
        newChecks.add(name);
      }
    }

    if (newChecks.isNotEmpty) {
      if (mounted) {
        setState(() {
          _checkedIngredients.addAll(newChecks);
        });
      }
    }
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

  // Helper for deep copy
  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    try {
      // Use toEncodable to handle Datetime/Timestamp or other objects safely
      return json.decode(
          json.encode(source, toEncodable: (object) => object.toString()));
    } catch (e) {
      return _manualDeepCopy(source);
    }
  }

  Map<String, dynamic> _manualDeepCopy(Map<String, dynamic> source) {
    final copy = <String, dynamic>{};
    source.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        copy[key] = _manualDeepCopy(value);
      } else if (value is Map) {
        // Handle generic maps by casting if possible or copying
        copy[key] = _manualDeepCopy(Map<String, dynamic>.from(value));
      } else if (value is List) {
        copy[key] = value.map((item) {
          if (item is Map<String, dynamic>) return _manualDeepCopy(item);
          if (item is Map)
            return _manualDeepCopy(Map<String, dynamic>.from(item));
          return item; // Primitives are copied by value (except objects, but we assume simple data)
        }).toList();
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  String _cleanInstructionText(String text, String target, String replacement) {
    // 1. naive replace
    // 2. remove adjectives preceding the replacement
    // e.g. "minced Garlic Powder" -> "Garlic Powder"

    // First, do the replacement
    final regex = RegExp(RegExp.escape(target), caseSensitive: false);
    String newText = text.replaceAllMapped(regex, (match) => replacement);

    // Now look for adjectives before the *new* ingredient name
    // Common prep words: chopped, minced, diced, sliced, grated, crushed, peeled
    final prepWords = [
      'chopped',
      'minced',
      'diced',
      'sliced',
      'grated',
      'crushed',
      'peeled',
      'finely'
    ];

    for (final word in prepWords) {
      // Case insensitive check for "word replacement"
      final pattern = RegExp(r'\b' + word + r'\s+' + RegExp.escape(replacement),
          caseSensitive: false);
      newText = newText.replaceAllMapped(pattern, (match) => replacement);
    }

    return newText;
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

    final recipe = _showOriginal ? _originalRecipe : _currentRecipe;
    final ingredients = (recipe['ingredients'] as List?) ?? [];
    final instructions = (recipe['instructions'] as List?) ?? [];

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
                actions: [], // Actions moved to Body
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Hero(
                          tag:
                              'recipe_thumb_${recipe['recipe_id'] ?? recipe['title']}',
                          child: Builder(builder: (context) {
                            if (imageUrl!.startsWith('data:')) {
                              try {
                                return Image.memory(
                                  base64Decode(imageUrl!.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[900],
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
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.surfaceDark,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: Colors.white10, size: 64),
                                );
                              },
                            );
                          }),
                        )
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
                      // Title & Notes
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              recipe['title'] ?? 'Recipe Details',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                fontFamily:
                                    'Plus Jakarta Sans', // Ensure premium font usage if available
                              ),
                            ),
                          ),
                          // Private/Public Badge? (Optional, based on ReciMe image)
                        ],
                      ),

                      const SizedBox(height: 16),

                      // VERSION SWITCHER (Original / My Version)
                      if (_isEdited) ...[
                        _buildPremiumVersionSwitcher(),
                        const SizedBox(height: 24),
                      ],

                      // ACTION ROW (Bookmark, Calendar, Shop, Share)
                      _buildReciMeActionRow(recipe),

                      const SizedBox(height: 32),

                      // NUTRITION RING
                      _buildNutritionSection(calories, protein, carbs, fat,
                          recipe['time'] ?? 'N/A'),

                      const SizedBox(height: 32),

                      // Ingredients Header (Serves) - Convert Removed
                      Row(
                        children: [
                          const Text(
                            "INGREDIENTS",
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Serves Stepper
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _updateServings(_currentServings - 1),
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: AppColors.zestyLime, size: 22),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    "$_currentServings serves",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _updateServings(_currentServings + 1),
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: AppColors.zestyLime, size: 22),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Ingredients List
                      _buildIngredientsList(ingredients),

                      const SizedBox(height: 40),

                      // INSTRUCTIONS HEADER
                      const Text(
                        "INSTRUCTIONS",
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
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

                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Start Cooking Button (Floating Sticky)
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.zestyLime.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.zestyLime,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Start Cooking",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      // FAB Assistant for chatting
      floatingActionButton: recipe['is_locked'] == true
          ? null
          : Padding(
              padding:
                  const EdgeInsets.only(bottom: 70.0), // Above start cooking
              child: FloatingActionButton.extended(
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
                backgroundColor: AppColors.surfaceDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                icon: const Icon(Icons.chat_bubble_outline,
                    color: AppColors.zestyLime, size: 20),
                label: const Text("Assistant",
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontWeight: FontWeight.bold)),
              ),
            ),
    );
  }

  // -- NEW BUILDERS --

  // 1. Premium Version Switcher
  Widget _buildPremiumVersionSwitcher() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          // Background Animation
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment:
                _showOriginal ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.45, // roughly half
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.zestyLime,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.zestyLime.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showOriginal = true),
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: Text("Original",
                        style: TextStyle(
                            color:
                                _showOriginal ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showOriginal = false),
                  behavior: HitTestBehavior.translucent,
                  child: Center(
                    child: Text("My Version",
                        style: TextStyle(
                            color:
                                !_showOriginal ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. ReciMe Style Action Row (With Real Logic)
  Widget _buildReciMeActionRow(Map<String, dynamic> recipe) {
    // We need to watch state to know if saved/shared
    return Consumer(builder: (context, ref, _) {
      final vaultState = ref.watch(vaultControllerProvider);
      final savedRecipes = vaultState.valueOrNull ?? [];
      final savedItem = savedRecipes.firstWhere(
        (r) => r['recipe_id'] == _currentRecipe['id'],
        orElse: () => {},
      );
      final isSaved = savedItem.isNotEmpty && savedItem['recipe_id'] != null;
      final isShared = isSaved && savedItem['is_shared'] == true;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // SAVE / BOOKMARK
          Stack(
            alignment: Alignment.center,
            children: [
              _buildCircularAction(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: isSaved ? "Saved" : "Save",
                isActive: isSaved,
                onTap: () async {
                  if (isSaved) {
                    // Confirm Delete
                    final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                              backgroundColor: AppColors.deepCharcoal,
                              title: const Text("Remove from Vault?",
                                  style: TextStyle(color: Colors.white)),
                              content: const Text(
                                  "This will remove this recipe from your saved collection.",
                                  style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Remove",
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ));
                    if (shouldDelete == true) {
                      await ref
                          .read(vaultControllerProvider.notifier)
                          .deleteRecipe(savedItem['recipe_id']);
                    }
                  } else {
                    // Save
                    // Ensure we save a clean copy but with edited flag if needed
                    final recipeToSave = _deepCopy(_currentRecipe);
                    if (_isEdited) {
                      recipeToSave['original_version'] =
                          _deepCopy(_originalRecipe);
                    }

                    await ref
                        .read(vaultControllerProvider.notifier)
                        .saveRecipe(recipeToSave);
                    if (mounted) {
                      _confettiController.play();
                      NanoToast.showSuccess(context, "Saved to Vault!");
                    }
                  }
                },
              ),
              // Confetti Blast from Button
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppColors.zestyLime,
                  Colors.white,
                  Colors.yellow,
                  Colors.green
                ],
                numberOfParticles: 20,
              ),
            ],
          ),

          // PLAN (Placeholder)
          _buildCircularAction(
            icon: Icons.calendar_today_outlined,
            label: "Plan",
            onTap: () =>
                NanoToast.showInfo(context, "Meal Planning coming soon!"),
          ),

          // SHOP
          _buildCircularAction(
            icon: Icons.shopping_basket_outlined,
            label: "Shop",
            onTap: () {
              _addMissingIngredientsToCart(
                  _currentRecipe['ingredients'] ?? [], context);
            },
          ),

          // SHARE
          _buildCircularAction(
            icon: isShared ? Icons.share : Icons.share_outlined,
            label: "Share",
            isActive: isShared,
            onTap: () {
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
                                  NanoToast.showInfo(context,
                                      "Please join a household first.");
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
                                  NanoToast.showSuccess(
                                      context, "Shared with Household!");
                              },
                            ),
                            ListTile(
                              leading:
                                  const Icon(Icons.link, color: Colors.white),
                              title: const Text("Share Link",
                                  style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalContext);
                                Share.share(
                                    "Check out this recipe: ${_currentRecipe['title']} on ChefMind!");
                              },
                            )
                          ],
                        ),
                      ));
            },
          ),
        ],
      );
    });
  }

  // Reuse existing helpers but commented out old AppBarActions to avoid duplication if kept in file
  // (We are replacing the definition so it's fine)

  Widget _buildCircularAction(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.zestyLime
                  : Colors.white.withOpacity(0.08),
              border: Border.all(
                  color: isActive ? AppColors.zestyLime : Colors.white12),
            ),
            child: Icon(icon,
                color: isActive ? Colors.black : Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // 3. Nutrition Section
  Widget _buildNutritionSection(
      double calories, double protein, double carbs, double fat, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Ring Chart
          SizedBox(
            width: 100,
            height: 100,
            child: NutritionCircle(
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNutrientLegend(
                    "Protein", "${protein.round()}g", AppColors.zestyLime),
                const SizedBox(height: 8),
                _buildNutrientLegend(
                    "Carbs", "${carbs.round()}g", AppColors.electricBlue),
                const SizedBox(height: 8),
                _buildNutrientLegend(
                    "Fats", "${fat.round()}g", const Color(0xFFFFC107)),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    Text(time,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNutrientLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }

  // Replacing _buildAppBarActions purely to clean up file, though it's not used in AppBar anymore.
  // Actually, I can just not include it here, but I must provide valid replacement for the range.
  // I will just stub it out or remove it.

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

  Widget _buildIngredientsList(List<dynamic> ingredients) {
    // List<dynamic> ingredients = List.from(_currentRecipe['ingredients'] ?? []); -- REMOVED: Uses argument now

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
        mainSection.add(item);
      }
    }

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

    final name = mapItem['name'].toString();
    final amount = ScalingHelper.scaleAmount(
        mapItem['amount'].toString(),
        (mapItem['amount'] == null || mapItem['amount'].toString().isEmpty)
            ? 1.0
            : (_currentServings / _baseServings));

    final isChecked = _checkedIngredients.contains(name);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isChecked) {
            _checkedIngredients.remove(name);
          } else {
            _checkedIngredients.add(name);
          }
        });
      },
      child: AnimatedContainer(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isChecked
              ? AppColors.zestyLime.withOpacity(0.05)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isChecked
                  ? AppColors.zestyLime.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            // Checkbox (Custom Circle)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? AppColors.zestyLime : Colors.transparent,
                border: Border.all(
                    color: isChecked ? AppColors.zestyLime : Colors.white24,
                    width: 2),
              ),
              alignment: Alignment.center,
              child: isChecked
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),

            // Emoji Container
            // Emoji Container
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: EmojiHelper.getEmoji(name) != null
                  ? Text(
                      EmojiHelper.getEmoji(name)!,
                      style: const TextStyle(fontSize: 20),
                    )
                  : Icon(Icons.restaurant_menu_rounded,
                      color: Colors.white.withOpacity(0.5), size: 18),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                        color: isChecked ? Colors.white54 : Colors.white,
                        fontWeight:
                            isChecked ? FontWeight.normal : FontWeight.w600,
                        fontSize: 15,
                        decoration:
                            isChecked ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white24),
                  ),
                  if (amount.isNotEmpty && amount != 'null')
                    Text(
                      amount, // E.g "2 cups"
                      style: TextStyle(
                        color: isChecked ? Colors.white24 : Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            // Add to cart button (only if not checked)
            if (!isChecked)
              IconButton(
                icon: const Icon(Icons.add_shopping_cart,
                    size: 20, color: AppColors.zestyLime),
                onPressed: () {
                  ref.read(shoppingControllerProvider.notifier).addItem(
                        name,
                        amount: amount.isEmpty ? '1' : amount,
                        category: 'Recipe Addon',
                      );
                  NanoToast.showInfo(context, "Added to list");
                },
              )
          ],
        ),
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

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.zestyLime.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.restaurant_menu,
                            color: AppColors.zestyLime, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.chefSays,
                          style: const TextStyle(
                              color: AppColors.zestyLime,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Question
                  Text('Q: "$question"',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 12),

                  // Answer
                  Text(displayText,
                      style: const TextStyle(
                          color: Colors.white, height: 1.5, fontSize: 16)),

                  if (modification != null) ...[
                    const SizedBox(height: 24),
                    // Modification Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.zestyLime,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_fix_high,
                                  color: Colors.black, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.chefSuggestedChange,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(actionText,
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: Colors.white70,
                          ),
                          child: Text(l10n.shoppingClearDialogCancel),
                        ),
                      ),
                      if (modification != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyModification(modification);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.zestyLime,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(l10n.chefApplyChange,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Done",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]
                    ],
                  )
                ],
              ),
            ),
          );
        });
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
                          .timeout(const Duration(seconds: 15));

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
                      // Close thinking dialog shortly on error
                      if (mounted) navigator.pop();

                      String errorMessage = e.toString();
                      if (e is TimeoutException ||
                          NetworkErrorView.isNetworkError(e)) {
                        errorMessage =
                            "No connection. Please check your internet.";
                      } else {
                        errorMessage =
                            errorMessage.replaceAll('Exception: ', '');
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
        // Paranoid: Copy the item even if unchanged to break reference with _originalRecipe
        if (item is Map) {
          newIngredients.add(Map<String, dynamic>.from(item));
        } else {
          newIngredients.add(item);
        }
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

        List<dynamic> newInstructions = [];
        for (var step in currentInstructions) {
          String stepText = step.toString();
          if (stepText.toLowerCase().contains(target)) {
            // Replace all occurrences with cleaning
            String newText =
                _cleanInstructionText(stepText, target, replacementName);
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
