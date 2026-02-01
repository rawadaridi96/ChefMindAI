import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/recipes/presentation/recipe_controller.dart';
import 'package:chefmind_ai/core/widgets/premium_paywall.dart';
import 'package:chefmind_ai/features/auth/data/auth_repository.dart';
import 'package:chefmind_ai/features/pantry/presentation/pantry_controller.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'package:chefmind_ai/features/subscription/presentation/subscription_controller.dart';
import 'package:chefmind_ai/core/widgets/network_error_view.dart';
import 'package:chefmind_ai/features/recipes/presentation/generation_options_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PantryGeneratorWidget extends ConsumerStatefulWidget {
  final VoidCallback onGenerate;
  final bool applyDietaryProfile;
  final ValueChanged<bool> onDietaryChanged;

  /// Optional GlobalKeys for onboarding targets
  final GlobalKey? filterButtonKey;
  final GlobalKey? selectorGroupKey;
  final GlobalKey? pantryGenerateKey;

  const PantryGeneratorWidget({
    super.key,
    required this.onGenerate,
    required this.applyDietaryProfile,
    required this.onDietaryChanged,
    this.filterButtonKey,
    this.selectorGroupKey,
    this.pantryGenerateKey,
  });

  @override
  ConsumerState<PantryGeneratorWidget> createState() =>
      _PantryGeneratorWidgetState();
}

class _PantryGeneratorWidgetState extends ConsumerState<PantryGeneratorWidget> {
  final TextEditingController _allergyController = TextEditingController();

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  // --- Lists & Getters --- //

  List<String> get _mealTypes {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.generatorMealTypeBreakfast,
      l10n.generatorMealTypeMainMeal,
      l10n.generatorMealTypeDessert,
      l10n.generatorMealTypeSnack,
      l10n.generatorMealTypeSurpriseMe,
    ];
  }

  List<String> get _cuisines {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.cuisineItalian,
      l10n.cuisineMexican,
      l10n.cuisineAsian,
      l10n.cuisineMediterranean,
      l10n.cuisineAmerican,
      l10n.cuisineFrench,
      l10n.cuisineIndian,
      l10n.cuisineMiddleEastern,
    ];
  }

  final List<int> _timeOptions = [15, 30, 45, 60];

  List<String> get _skillLevels {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.skillBeginner,
      l10n.skillIntermediate,
      l10n.skillPro,
    ];
  }

  List<String> get _availableFilters {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.generatorFilterGourmet,
      l10n.generatorFilterHealthy,
      l10n.generatorFilterVegan,
      l10n.generatorFilterKeto,
      l10n.generatorFilterLowCarb,
      l10n.generatorFilterHighProtein,
      l10n.generatorFilterComfort,
      l10n.generatorFilterExotic,
    ];
  }

  final List<String> _moods = [
    'Comfort',
    'Date Night',
    'Quick & Easy',
    'Energetic',
    'Adventurous',
    'Fancy'
  ];

  String _getLocalizedMood(String mood) {
    final l10n = AppLocalizations.of(context)!;
    switch (mood) {
      case 'Comfort':
        return l10n.homeMoodComfort;
      case 'Date Night':
        return l10n.homeMoodDateNight;
      case 'Quick & Easy':
        return l10n.homeMoodQuickEasy;
      case 'Energetic':
        return l10n.homeMoodEnergetic;
      case 'Adventurous':
        return l10n.homeMoodAdventurous;
      case 'Fancy':
        return l10n.homeMoodFancy;
      default:
        return mood;
    }
  }

  // --- Build --- //

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeControllerProvider);
    final options = ref.watch(generationOptionsControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final pantryState = ref.watch(pantryControllerProvider);

    // Dietary Logic (Match Discover Tab)
    final user = ref.watch(authRepositoryProvider).currentUser;
    final subState = ref.watch(subscriptionControllerProvider);
    final tier = subState.valueOrNull ?? SubscriptionTier.homeCook;
    final isPremium = tier != SubscriptionTier.homeCook;
    final prefs = user?.userMetadata?['dietary_preferences'];
    final hasPreferences = prefs != null && prefs is List && prefs.isNotEmpty;
    // Allow toggle if premium AND has preferences set
    final isDietaryEnabled = hasPreferences && isPremium;

    void handleDietaryToggle(bool val) {
      if (!isPremium) {
        PremiumPaywall.show(context,
            featureName: l10n.premiumFeatureADI,
            message: l10n.premiumADISous,
            ctaLabel: l10n.premiumUpgradeToSous);
        return;
      }
      if (!hasPreferences) {
        NanoToast.showInfo(context, "Set your profile in Settings first 🧑‍🍳");
        return;
      }
      widget.onDietaryChanged(val);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Preferences Row (Moved Up)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Filter Button
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                key: widget.filterButtonKey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: (options.filters.isNotEmpty ||
                          (options.allergies?.isNotEmpty ?? false) ||
                          options.cuisine != null ||
                          options.maxTime != null ||
                          options.skillLevel != null)
                      ? AppColors.zestyLime.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (options.filters.isNotEmpty ||
                              (options.allergies?.isNotEmpty ?? false) ||
                              options.cuisine != null ||
                              options.maxTime != null ||
                              options.skillLevel != null)
                          ? AppColors.zestyLime.withOpacity(0.5)
                          : Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune,
                        size: 16,
                        color: (options.filters.isNotEmpty)
                            ? AppColors.zestyLime
                            : Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      "Filters${options.filters.isNotEmpty ? ' (${options.filters.length})' : ''}",
                      style: TextStyle(
                          color: (options.filters.isNotEmpty)
                              ? AppColors.zestyLime
                              : Colors.white70,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Dietary Profile Toggle (Enhanced)
            Opacity(
              opacity: isDietaryEnabled ? 1.0 : 0.5,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        handleDietaryToggle(!widget.applyDietaryProfile),
                    child: Row(
                      children: [
                        Text(
                          l10n.homeDietaryProfile,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                        if (!isPremium) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.lock_outline,
                              color: AppColors.zestyLime, size: 12),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: isDietaryEnabled && widget.applyDietaryProfile,
                    onChanged: (val) => handleDietaryToggle(val),
                    activeColor: AppColors.zestyLime,
                    activeTrackColor: AppColors.zestyLime.withOpacity(0.2),
                    inactiveThumbColor: Colors.white54,
                    inactiveTrackColor: Colors.white10,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. Selector Group (Glassy Look)
        Container(
          key: widget.selectorGroupKey,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              // Meal Type Selector
              _buildSelectorTile(
                context,
                icon: Icons.restaurant,
                label: l10n.recipesMealType,
                value: options.mealType ?? l10n.generatorMealTypeSurpriseMe,
                onTap: () => _showMealTypePicker(context),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.1)),
              // Vibe Selector
              _buildSelectorTile(
                context,
                icon: Icons.emoji_objects_outlined,
                label: l10n.generatorVibe,
                value: options.mood ?? "Any",
                isLocked:
                    ref.watch(subscriptionControllerProvider).valueOrNull !=
                        SubscriptionTier.executiveChef,
                onTap: () => _showMoodPicker(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Generate Button
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();

            if (pantryState.hasError) {
              if (NetworkErrorView.isNetworkError(pantryState.error!)) {
                NanoToast.showError(
                    context, AppLocalizations.of(context)!.errorNoConnection);
              } else {
                NanoToast.showError(
                    context, AppLocalizations.of(context)!.errorGeneric);
              }
              return;
            }

            final pantryItems = pantryState.valueOrNull ?? [];
            if (pantryItems.isEmpty) {
              NanoToast.showInfo(
                context,
                "${l10n.generatorPantryEmptyTitle}\n${l10n.generatorPantryEmptyDesc}",
              );
              return;
            }

            ref.read(recipeControllerProvider.notifier).generate(
                  mode: 'pantry_chef',
                  mealType: options.mealType,
                  mood: options.mood,
                  filters: options.filters,
                  allergies: options.allergies,
                  cuisine: options.cuisine,
                  maxTime: options.maxTime,
                  skillLevel: options.skillLevel,
                  includeGlobalDiet: isPremium && widget.applyDietaryProfile,
                );
            widget.onGenerate();
          },
          child: Container(
            key: widget.pantryGenerateKey,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.zestyLime,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.zestyLime.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            alignment: Alignment.center,
            child: state.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.deepCharcoal,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: AppColors.deepCharcoal),
                      const SizedBox(width: 12),
                      Text(
                        l10n.generatorGenerateRecipes,
                        style: const TextStyle(
                          color: AppColors.deepCharcoal,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // --- Helpers --- //

  Widget _buildSelectorTile(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      required VoidCallback onTap,
      bool isLocked = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.zestyLime, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      if (isLocked) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.lock, size: 14, color: Colors.white30)
                      ]
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  void _showMealTypePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepCharcoal,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.recipesMealType,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._mealTypes.map((type) => ListTile(
                  title:
                      Text(type, style: const TextStyle(color: Colors.white)),
                  trailing:
                      ref.read(generationOptionsControllerProvider).mealType ==
                              type
                          ? const Icon(Icons.check, color: AppColors.zestyLime)
                          : null,
                  onTap: () {
                    ref
                        .read(generationOptionsControllerProvider.notifier)
                        .setMealType(type);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showMoodPicker(BuildContext context) {
    final isExecutive = ref.read(subscriptionControllerProvider).valueOrNull ==
        SubscriptionTier.executiveChef;
    if (!isExecutive) {
      PremiumPaywall.show(context,
          featureName: "Mood-Based Suggestions",
          message: "Unlock precise mood-based cooking with Executive Chef.",
          ctaLabel: "Upgrade to Executive Chef");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepCharcoal,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.generatorVibe,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                title: const Text("Any", style: TextStyle(color: Colors.white)),
                trailing:
                    ref.read(generationOptionsControllerProvider).mood == null
                        ? const Icon(Icons.check, color: AppColors.zestyLime)
                        : null,
                onTap: () {
                  ref
                      .read(generationOptionsControllerProvider.notifier)
                      .setMood(null);
                  Navigator.pop(context);
                },
              ),
              ..._moods.map((mood) => ListTile(
                    title: Text(_getLocalizedMood(mood),
                        style: const TextStyle(color: Colors.white)),
                    trailing: ref
                                .read(generationOptionsControllerProvider)
                                .mood ==
                            mood
                        ? const Icon(Icons.check, color: AppColors.zestyLime)
                        : null,
                    onTap: () {
                      ref
                          .read(generationOptionsControllerProvider.notifier)
                          .setMood(mood);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final options = ref.watch(generationOptionsControllerProvider);
          final notifier =
              ref.read(generationOptionsControllerProvider.notifier);

          // Sync local controller if changed externally (e.g. reset)
          if (options.allergies != _allergyController.text) {
            final text = options.allergies ?? '';
            if (text != _allergyController.text) {
              _allergyController.text = text;
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppColors.deepCharcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          AppLocalizations.of(context)!.generatorFiltersAndDiet,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          notifier.reset();
                          _allergyController.clear();
                        },
                        child: Text(
                            AppLocalizations.of(context)!.generatorReset,
                            style: const TextStyle(color: Colors.white54)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Cuisine
                          Text(AppLocalizations.of(context)!.generatorCuisine,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _cuisines.map((c) {
                              final isSelected = options.cuisine == c;
                              return FilterChip(
                                label: Text(c),
                                selected: isSelected,
                                onSelected: (val) =>
                                    notifier.setCuisine(val ? c : null),
                                backgroundColor: Colors.white10,
                                selectedColor: AppColors.zestyLime,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.deepCharcoal
                                        : Colors.white),
                                checkmarkColor: AppColors.deepCharcoal,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // 2. Max Time
                          Text(AppLocalizations.of(context)!.generatorMaxTime,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _timeOptions.map((t) {
                              final isSelected = options.maxTime == t;
                              return FilterChip(
                                label: Text(
                                    "$t ${AppLocalizations.of(context)!.unitMinutes}"),
                                selected: isSelected,
                                onSelected: (val) =>
                                    notifier.setMaxTime(val ? t : null),
                                backgroundColor: Colors.white10,
                                selectedColor: AppColors.zestyLime,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.deepCharcoal
                                        : Colors.white),
                                checkmarkColor: AppColors.deepCharcoal,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // 3. Skill Level
                          Text(
                              AppLocalizations.of(context)!.generatorSkillLevel,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _skillLevels.map((s) {
                              final isSelected = options.skillLevel == s;
                              return FilterChip(
                                label: Text(s),
                                selected: isSelected,
                                onSelected: (val) =>
                                    notifier.setSkillLevel(val ? s : null),
                                backgroundColor: Colors.white10,
                                selectedColor: AppColors.zestyLime,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.deepCharcoal
                                        : Colors.white),
                                checkmarkColor: AppColors.deepCharcoal,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // 4. Other Filters
                          Text(
                              AppLocalizations.of(context)!
                                  .generatorDietaryLabels,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableFilters.map((filter) {
                              final isSelected =
                                  options.filters.contains(filter);
                              return FilterChip(
                                label: Text(filter),
                                selected: isSelected,
                                onSelected: (_) =>
                                    notifier.toggleFilter(filter),
                                backgroundColor: Colors.white10,
                                selectedColor: AppColors.zestyLime,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.deepCharcoal
                                        : Colors.white),
                                checkmarkColor: AppColors.deepCharcoal,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // 5. Allergies
                          Text(
                              AppLocalizations.of(context)!
                                  .generatorAllergiesExclusions,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _allergyController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!
                                  .generatorAllergiesHint,
                              hintStyle: const TextStyle(color: Colors.white30),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (val) => notifier.setAllergies(val),
                          ),
                          const SizedBox(height: 60), // Space for FAB/Button
                        ],
                      ),
                    ),
                  ),

                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.zestyLime,
                          foregroundColor: AppColors.deepCharcoal),
                      child: Text(AppLocalizations.of(context)!.generalDone),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
