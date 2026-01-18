import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/features/recipes/presentation/widgets/conflict_resolution_dialog.dart';
import '../../onboarding/presentation/entry_orchestrator.dart';
import 'recipe_controller.dart';
import '../../shopping/presentation/shopping_controller.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/widgets/nano_toast.dart';
import 'vault_controller.dart';
import '../../auth/presentation/auth_state_provider.dart'; // Import provider
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shopping/data/retail_unit_helper.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/widgets/premium_paywall.dart';
import '../../../../core/exceptions/premium_limit_exception.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  late Map<String, dynamic> _currentRecipe;
  late Map<String, dynamic> _originalRecipe;
  bool _isEdited = false;
  bool _showOriginal = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
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

    if (_currentRecipe['is_locked'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLockedContentModal();
      });
    }
  }

  void _toggleView() {
    setState(() {
      _showOriginal = !_showOriginal;
    });
  }

  void _showConsultChefDialog() {
    final TextEditingController questionController = TextEditingController();

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
              const Text(
                'AI Chef Assistant 👨‍🍳',
                style: TextStyle(
                    color: AppColors.zestyLime,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask about substitutions, techniques, or equipment alternatives.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: questionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Can I use almond milk instead?',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                        builder: (context) => const Center(
                              child: Card(
                                color: AppColors.deepCharcoal,
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                          color: AppColors.zestyLime),
                                      SizedBox(height: 16),
                                      Text("Chef is thinking...",
                                          style: TextStyle(color: Colors.white))
                                    ],
                                  ),
                                ),
                              ),
                            ));

                    try {
                      final result = await ref
                          .read(recipeControllerProvider.notifier)
                          .consultChef(
                              question, _currentRecipe['title'] ?? 'Recipe')
                          .timeout(const Duration(seconds: 60));

                      // Close thinking dialog
                      if (mounted) navigator.pop();

                      String displayText =
                          result['answer'] ?? "No answer provided.";
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
                        errorMessage =
                            "The Chef is taking a little longer than usual. Please try again! (Timeout)";
                      }

                      NanoToast.showError(context, errorMessage);
                    }
                  },
                  child: const Text('Ask Chef'),
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
    showDialog(
        context: context,
        builder: (context) {
          String actionText = '';
          if (modification != null) {
            final type = modification['type'];
            final target = modification['target_ingredient'];
            final replacement = modification['replacement_ingredient'];

            if (type == 'replace') {
              actionText = "Swap $target with $replacement";
            } else if (type == 'remove') {
              actionText = "Remove $target";
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF252525),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Chef Says:',
                style: TextStyle(color: AppColors.zestyLime)),
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
                        const Text("Suggested Change",
                            style: TextStyle(
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
                  child: const Text('Apply Change',
                      style: TextStyle(
                          color: AppColors.zestyLime,
                          fontWeight: FontWeight.bold)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(color: Colors.white54)),
              )
            ],
          );
        });
  }

  Future<void> _applyModification(Map<String, dynamic> mod) async {
    final type = mod['type'];
    final target = mod['target_ingredient'].toString().toLowerCase();
    // Determine replacement (if any)
    final replacement = mod['replacement_ingredient']?.toString();

    final List<dynamic> ingredients =
        List.from(_currentRecipe['ingredients'] ?? []);
    bool applied = false;

    final newIngredients = <dynamic>[];
    final Set<String> matchedFullNames = {};

    for (var item in ingredients) {
      String itemName = '';
      if (item is Map) {
        itemName = item['name'].toString();
      } else {
        itemName = item.toString();
      }

      if (itemName.toLowerCase().contains(target)) {
        applied = true;
        matchedFullNames.add(itemName);
        if (type == 'replace' && replacement != null) {
          if (item is Map) {
            newIngredients.add({...item, 'name': replacement});
          } else {
            newIngredients.add(replacement);
          }
        } else if (type == 'remove') {
          // Skip adding = remove
          continue;
        }
      } else {
        newIngredients.add(item);
      }
    }

    if (applied) {
      final newRecipe = Map<String, dynamic>.from(_currentRecipe);
      newRecipe['ingredients'] = newIngredients;

      // Handle Instruction Updates for Replacements
      if (type == 'replace' && replacement != null) {
        final List<dynamic> instructions =
            List.from(_currentRecipe['instructions'] ?? []);
        final newInstructions = instructions.map((step) {
          String stepStr = step.toString();
          final String replacementText = _toTitleCase(replacement!);

          // 1. Replace captured full ingredient names first
          for (final fullName in matchedFullNames) {
            final RegExp fullExp =
                RegExp(RegExp.escape(fullName), caseSensitive: false);
            stepStr =
                stepStr.replaceAllMapped(fullExp, (match) => replacementText);
          }

          // 2. Replace the raw target keyword
          final RegExp targetExp =
              RegExp(RegExp.escape(target), caseSensitive: false);

          if (!replacementText.toLowerCase().contains(target)) {
            stepStr =
                stepStr.replaceAllMapped(targetExp, (match) => replacementText);
          }

          return stepStr;
        }).toList();
        newRecipe['instructions'] = newInstructions;
      }

      // Also Capitalize the ingredient list replacement
      if (type == 'replace' && replacement != null) {
        final String capReplacement = _toTitleCase(replacement);
        // (Re-run the loop or just update the one we already made?
        // We already made newIngredients list above but with raw replacement.
        // Let's quick-fix the newIngredients list for better performance than re-looping?
        // Actually, iterate again or just do it right the first time.
        // Let's refactor the loop slightly to use capitalization there too.
        // Wait, 'newIngredients' is already built. Let's just map it.)
        for (var i = 0; i < newIngredients.length; i++) {
          if (newIngredients[i] is Map &&
              newIngredients[i]['name'] == replacement) {
            newIngredients[i]['name'] = capReplacement;
          } else if (newIngredients[i] == replacement) {
            newIngredients[i] = capReplacement;
          }
        }
      }

      setState(() {
        _currentRecipe = newRecipe;
        _isEdited = true;
        _showOriginal = false; // Show the edited version
      });

      NanoToast.showSuccess(
          context, "Recipe updated! Use the toggle to view original.");

      // NO DB Update for now to keep local toggle clean for session
      /* 
       if (_currentRecipe['id'] != null) {
          await ref.read(recipeControllerProvider.notifier).updateRecipe(_currentRecipe['id'], {'ingredients': newIngredients});
       }
       */
    } else {
      NanoToast.showError(context, "Could not find ingredient to modify.");
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
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
            NanoToast.showSuccess(context, "Recipe Unlocked!");
          }
        });
      }
    });

    // Determine which recipe to show
    final recipe = _showOriginal ? _originalRecipe : _currentRecipe;

    final ingredients = (recipe['ingredients'] as List?) ?? [];
    final instructions = (recipe['instructions'] as List?) ?? [];
    final equipment = (recipe['equipment'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        title: Text(recipe['title'] ?? 'Recipe Details',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.zestyLime),
        actions: [
          // Save Button
          // Save Button
          // Save Button
          // Save Button
          if (recipe['is_locked'] != true)
            Consumer(
              builder: (context, ref, child) {
                final vaultState = ref.watch(vaultControllerProvider);
                final savedRecipes = vaultState.valueOrNull ?? [];

                // Check if saved by matching ID or Title (fallback for legacy)
                final isSaved = savedRecipes.any((r) {
                  final idMatch = r['recipe_id'] != null &&
                      r['recipe_id'] == _currentRecipe['id'];
                  // If ID is missing (fresh generation), we can't match by ID yet, returning false.
                  // Unless we matched by title? But titles can be duplicates.
                  // Relying on ID is safer. If it has no ID, it's likely not saved.
                  return idMatch;
                });

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      // Ensure filled icon when saved
                      icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border),
                      color: AppColors.zestyLime,
                      onPressed: () async {
                        if (isSaved) {
                          // Start delete flow
                          final savedItem = savedRecipes.firstWhere(
                              (r) => r['recipe_id'] == _currentRecipe['id'],
                              orElse: () => {});
                          if (savedItem.isNotEmpty &&
                              savedItem['recipe_id'] != null) {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: AppColors.deepCharcoal,
                                title: const Text("Delete Recipe?",
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                    "Are you sure you want to remove this from your Vault?",
                                    style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Cancel",
                                        style:
                                            TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Delete",
                                        style: TextStyle(
                                            color: AppColors.errorRed,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );

                            if (shouldDelete == true) {
                              await ref
                                  .read(vaultControllerProvider.notifier)
                                  .deleteRecipe(savedItem['recipe_id']);
                              if (mounted) {
                                NanoToast.showInfo(
                                    context, 'Recipe removed from Vault');
                              }
                            }
                          }
                        } else {
                          // Save flow
                          // 1. Check for duplicate title first
                          final title = _currentRecipe['title'];
                          final existingId = await ref
                              .read(vaultControllerProvider.notifier)
                              .checkForDuplicate(title);

                          // If existingId found AND it's different from our current ID
                          // (meaning not just re-saving the same file we already have open)
                          if (existingId != null &&
                              existingId != _currentRecipe['id']) {
                            // Conflict Detected!
                            final choice = await showDialog<String>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => ConflictResolutionDialog(
                                title: title,
                                onOverwrite: () =>
                                    Navigator.pop(context, 'overwrite'),
                                onSaveAsNew: () =>
                                    Navigator.pop(context, 'new'),
                                onCancel: () =>
                                    Navigator.pop(context, 'cancel'),
                              ),
                            );

                            if (choice == 'cancel' || choice == null) return;

                            if (choice == 'overwrite') {
                              // Use existing ID to overwrite
                              _currentRecipe['id'] = existingId;
                            } else if (choice == 'new') {
                              // Smart Versioning: Check if title ends with " V<number>"
                              final versionRegex = RegExp(r' V(\d+)$');
                              final match = versionRegex.firstMatch(title);

                              if (match != null) {
                                // Has version, increment it
                                final version = int.parse(match.group(1)!);
                                _currentRecipe['title'] = title.replaceFirst(
                                    versionRegex, " V${version + 1}");
                              } else {
                                // No version, append V2
                                _currentRecipe['title'] = "$title V2";
                              }
                              _currentRecipe
                                  .remove('id'); // Ensure fresh ID generation
                            }
                          }

                          // Prepare recipe for saving
                          final recipeToSave =
                              Map<String, dynamic>.from(_currentRecipe);
                          if (_isEdited) {
                            recipeToSave['original_version'] = _originalRecipe;
                          }

                          try {
                            await ref
                                .read(vaultControllerProvider.notifier)
                                .saveRecipe(recipeToSave);
                          } on PremiumLimitReachedException catch (e) {
                            if (context.mounted) {
                              PremiumPaywall.show(context,
                                  message: e.message,
                                  featureName: e.featureName);
                            }
                            return; // Stop execution (confetti, success toast)
                          } catch (e) {
                            if (context.mounted) {
                              NanoToast.showError(context, e.toString());
                            }
                            return;
                          }

                          // Sync generated ID back to current recipe state so UI updates
                          if (recipeToSave['id'] != null) {
                            _currentRecipe['id'] = recipeToSave['id'];
                          }

                          if (mounted) {
                            _confettiController.play();
                            NanoToast.showSuccess(
                                context, 'Recipe saved to Vault!');
                            // Force rebuild to pick up new ID if it was assigned on the map
                            setState(() {});
                          }
                        }
                      },
                    ),
                    ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        AppColors.zestyLime,
                        Colors.white,
                        AppColors.electricBlue
                      ],
                      numberOfParticles: 20,
                      gravity: 0.1,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      floatingActionButton: recipe['is_locked'] == true
          ? null
          : FloatingActionButton.extended(
              onPressed: _showConsultChefDialog,
              backgroundColor: AppColors.zestyLime,
              icon: const Icon(Icons.chat_bubble_outline,
                  color: AppColors.deepCharcoal),
              label: const Text('Assistant',
                  style: TextStyle(
                      color: AppColors.deepCharcoal,
                      fontWeight: FontWeight.bold)),
            ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEdited) ...[
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: Colors.white24)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Original",
                              style: TextStyle(
                                  color: _showOriginal
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 12, // Reduced font size
                                  fontWeight: _showOriginal
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          Transform.scale(
                            scale: 0.8, // Reduced scale
                            child: Switch(
                              value: !_showOriginal,
                              onChanged: (value) =>
                                  setState(() => _showOriginal = !value),
                              activeColor: AppColors.zestyLime,
                              activeTrackColor:
                                  AppColors.zestyLime.withOpacity(0.2),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.white10,
                            ),
                          ),
                          Text("My Version",
                              style: TextStyle(
                                  color: !_showOriginal
                                      ? AppColors.zestyLime
                                      : Colors.white54,
                                  fontSize: 12, // Reduced font size
                                  fontWeight: !_showOriginal
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ],
                      ),
                    ),
                  ),
                ],
                // Header Stats
                // Nutrition Hub
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      // Top Row: Time & Calories
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatBadge(Icons.timer, recipe['time'] ?? 'N/A'),
                          _buildStatBadge(Icons.local_fire_department,
                              recipe['calories'] ?? 'N/A'),
                        ],
                      ),

                      if (recipe['macros'] != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: Colors.white10),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                                child: _buildMacroItem("Protein",
                                    recipe['macros']['protein'] ?? '?')),
                            Expanded(
                                child: _buildMacroItem(
                                    "Carbs", recipe['macros']['carbs'] ?? '?')),
                            Expanded(
                                child: _buildMacroItem(
                                    "Fat", recipe['macros']['fat'] ?? '?')),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Equipment List (Horizontal)
                if (equipment.isNotEmpty) ...[
                  const Text("Equipment Needed",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: equipment
                          .map((e) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(e.toString(),
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Ingredients
                const Text("Ingredients",
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),

                const SizedBox(height: 12),

                // Add to Cart Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Logic to add missing items
                      int addedCount = 0;
                      for (var item in ingredients) {
                        if (item is Map && item['is_missing'] == true) {
                          // Extract core name
                          final rawName = item['name'].toString();
                          final coreName =
                              RetailUnitHelper.extractCoreIngredientName(
                                  rawName);

                          ref.read(shoppingControllerProvider.notifier).addItem(
                              coreName,
                              amount: '', // Explicitly empty per user request
                              category: 'Recipe Import',
                              recipeSource:
                                  recipe['title'] // Add source tracking!
                              );
                          addedCount++;
                        }
                      }
                      if (addedCount > 0) {
                        toastification.show(
                          context: context,
                          type: ToastificationType.success,
                          style: ToastificationStyle.flat,
                          title: Text("Added $addedCount items to Cart!"),
                          description: const Text("Ready for checkout."),
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: const Duration(seconds: 4),
                          backgroundColor: AppColors.deepCharcoal,
                          primaryColor: AppColors.zestyLime,
                          foregroundColor: Colors.white,
                          showProgressBar: false,
                          icon: const Icon(Icons.shopping_cart_checkout,
                              color: AppColors.zestyLime),
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.zestyLime),
                        );
                      } else {
                        NanoToast.showInfo(
                            context, 'No missing ingredients to add.');
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart,
                        color: AppColors.zestyLime),
                    label: const Text("Add Missing to Cart",
                        style: TextStyle(color: AppColors.zestyLime)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.zestyLime),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: ingredients.map((item) {
                      final mapItem = item is Map
                          ? item
                          : {
                              'name': item.toString(),
                              'amount': '',
                              'is_missing': false
                            };
                      final isMissing = mapItem['is_missing'] == true;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Icon(
                                  isMissing
                                      ? Icons.circle_outlined
                                      : Icons.check_circle,
                                  color: isMissing
                                      ? Colors.grey
                                      : AppColors.zestyLime,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              constraints: const BoxConstraints(
                                  minWidth: 40, maxWidth: 80),
                              child: Text("${mapItem['amount']} ",
                                  style: const TextStyle(
                                      color: AppColors.zestyLime,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Expanded(child: Builder(builder: (context) {
                              String fullText = mapItem['name'].toString();
                              // Regex to separate main content from parentheses
                              final RegExp exp = RegExp(r'^(.*?)(\(.*\))(.*)$');
                              final match = exp.firstMatch(fullText);

                              if (match != null) {
                                // We have parentheses
                                String mainPart = (match.group(1) ?? '') +
                                    (match.group(3) ?? '');
                                String notePart = match.group(2) ?? '';
                                return RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: mainPart.trim(),
                                        style: TextStyle(
                                            color: isMissing
                                                ? Colors.white54
                                                : Colors.white,
                                            fontSize: 15,
                                            height: 1.3),
                                      ),
                                      if (notePart.isNotEmpty)
                                        TextSpan(
                                          text: "\n${notePart.trim()}",
                                          style: TextStyle(
                                              color: isMissing
                                                  ? Colors.white30
                                                  : Colors.white54,
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              height: 1.4),
                                        ),
                                    ],
                                  ),
                                );
                              }

                              // Fallback
                              return Text(fullText,
                                  style: TextStyle(
                                      color: isMissing
                                          ? Colors.white54
                                          : Colors.white,
                                      fontSize: 15, // Slightly larger
                                      height: 1.3));
                            })),
                            // Individual Add to Cart Button
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart,
                                  color: Colors.white30, size: 20),
                              onPressed: () {
                                ref
                                    .read(shoppingControllerProvider.notifier)
                                    .addItem(mapItem['name'].toString(),
                                        amount: mapItem['amount']?.toString() ??
                                            '1',
                                        category: 'Recipe Addon');
                                NanoToast.showInfo(context,
                                    "Added ${mapItem['name']} to cart!");
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                const Text("Instructions",
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                const SizedBox(height: 12),
                if (recipe['is_locked'] == true) ...[
                  GestureDetector(
                    onTap: _showLockedContentModal,
                    child: Stack(
                      children: [
                        // Blurred Instructions Preview
                        Column(
                          children: [
                            ...List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                          color: Colors.white10,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        height: 16,
                                        color: Colors.white10,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
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
                                    const Text(
                                      "Recipe Locked",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _showLockedContentModal,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.zestyLime,
                                          foregroundColor:
                                              AppColors.deepCharcoal),
                                      child: const Text("Unlock Full Recipe"),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ] else ...[
                  ...instructions.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                color: AppColors.zestyLime,
                                shape: BoxShape.circle),
                            child: Text("${entry.key + 1}",
                                style: const TextStyle(
                                    color: AppColors.deepCharcoal,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Text(entry.value.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      height: 1.5,
                                      fontSize: 15))),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                const SizedBox(height: 80), // Fab space
              ],
            ),
          ),
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
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 80), // Prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.zestyLime, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.zestyLime,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
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
                  const Text(
                    "Unlock the Full Recipe",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You've reached your guest limit. Sign up for free to unlock this recipe and keep cooking!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
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
                    child: const Text(
                      "Sign Up for Free",
                      style: TextStyle(
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
                    child: const Text(
                      "Already have an account? Log In",
                      style: TextStyle(color: Colors.white54),
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

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}
