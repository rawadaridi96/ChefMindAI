import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/haptic_button.dart';
import 'package:chefmind_ai/features/recipes/presentation/recipe_controller.dart';
import 'package:chefmind_ai/features/pantry/presentation/pantry_controller.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'package:chefmind_ai/features/subscription/presentation/subscription_controller.dart';
import 'package:toastification/toastification.dart';
import 'package:chefmind_ai/core/widgets/network_error_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../generation_options_controller.dart';

class PantryGeneratorWidget extends ConsumerStatefulWidget {
  final VoidCallback onGenerate;
  final bool applyDietaryProfile;

  const PantryGeneratorWidget({
    super.key,
    required this.onGenerate,
    required this.applyDietaryProfile,
  });

  @override
  ConsumerState<PantryGeneratorWidget> createState() =>
      _PantryGeneratorWidgetState();
}

class _PantryGeneratorWidgetState extends ConsumerState<PantryGeneratorWidget> {
  // Local controller for text field to avoid rebuilding on every character
  final TextEditingController _allergyController = TextEditingController();

  List<String> get _mealTypes {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.generatorMealTypeSurpriseMe,
      l10n.generatorMealTypeBreakfast,
      l10n.generatorMealTypeMainMeal,
      l10n.generatorMealTypeDessert,
      l10n.generatorMealTypeSnack,
    ];
  }

  List<String> get _availableFilters {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.generatorFilterGourmet,
      l10n.generatorFilterHealthy,
      l10n.generatorFilter15Min,
      l10n.generatorFilterComfort,
      l10n.generatorFilterExotic,
      l10n.generatorFilterVegan,
      l10n.generatorFilterKeto,
      l10n.generatorFilterLowCarb,
      l10n.generatorFilterHighProtein,
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

  List<int> get _timeOptions => [15, 30, 45, 60, 90];

  List<String> get _skillLevels {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.skillBeginner,
      l10n.skillIntermediate,
      l10n.skillPro,
    ];
  }

  String _getLocalizedMood(String moodKey) {
    final l10n = AppLocalizations.of(context)!;
    switch (moodKey) {
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
        return moodKey;
    }
  }

  final List<String> _moods = [
    'Comfort',
    'Date Night',
    'Quick & Easy',
    'Energetic',
    'Adventurous',
    'Fancy'
  ];

  @override
  void initState() {
    super.initState();
    // Sync allergy text with controller if present (unlikely on first init but good practice)
    final initialAllergies =
        ref.read(generationOptionsControllerProvider).allergies;
    if (initialAllergies != null) {
      _allergyController.text = initialAllergies;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize default meal type if not set
    final currentMealType =
        ref.read(generationOptionsControllerProvider).mealType;
    if (currentMealType == null) {
      Future.microtask(() {
        ref.read(generationOptionsControllerProvider.notifier).setMealType(
            AppLocalizations.of(context)!.generatorMealTypeSurpriseMe);
      });
    }
  }

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeControllerProvider);
    final options = ref.watch(generationOptionsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Row: Meal Type & Filter Button
        SizedBox(
          height: 38,
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mealTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = _mealTypes[index];
                    final isSelected = type == options.mealType;
                    return GestureDetector(
                      onTap: () => ref
                          .read(generationOptionsControllerProvider.notifier)
                          .setMealType(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColors.zestyLime : Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(type,
                            style: TextStyle(
                                color: isSelected
                                    ? AppColors.deepCharcoal
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 38,
                  decoration: BoxDecoration(
                    color: (options.filters.isNotEmpty ||
                            (options.allergies?.isNotEmpty ?? false) ||
                            options.cuisine != null ||
                            options.maxTime != null ||
                            options.skillLevel != null)
                        ? AppColors.zestyLime.withOpacity(0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.tune,
                      size: 18,
                      color: (options.filters.isNotEmpty ||
                              (options.allergies?.isNotEmpty ?? false) ||
                              options.cuisine != null ||
                              options.maxTime != null ||
                              options.skillLevel != null)
                          ? AppColors.zestyLime
                          : Colors.white70),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Mood Selector
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _moods.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_objects_outlined,
                            size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.generatorVibe,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final mood = _moods[index - 1];
              final isSelected = options.mood == mood;
              final subscriptionState =
                  ref.watch(subscriptionControllerProvider);
              final isExecutive = subscriptionState.valueOrNull ==
                  SubscriptionTier.executiveChef;

              IconData moodIcon;
              switch (mood) {
                case 'Comfort':
                  moodIcon = Icons.fireplace;
                  break;
                case 'Date Night':
                  moodIcon = Icons.wine_bar;
                  break;
                case 'Quick & Easy':
                  moodIcon = Icons.bolt;
                  break;
                case 'Energetic':
                  moodIcon = Icons.fitness_center;
                  break;
                case 'Adventurous':
                  moodIcon = Icons.explore;
                  break;
                case 'Fancy':
                  moodIcon = Icons.diamond;
                  break;
                default:
                  moodIcon = Icons.star;
              }

              return GestureDetector(
                onTap: () {
                  if (!isExecutive) {
                    NanoToast.showError(context,
                        AppLocalizations.of(context)!.recipesUpgradeForMore);
                    return;
                  }
                  ref
                      .read(generationOptionsControllerProvider.notifier)
                      .setMood(isSelected ? null : mood);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.zestyLime
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(moodIcon,
                          size: 14,
                          color: isSelected
                              ? AppColors.deepCharcoal
                              : Colors.white54),
                      const SizedBox(width: 6),
                      Text(_getLocalizedMood(mood),
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.deepCharcoal
                                  : Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      if (!isExecutive) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock,
                            size: 10,
                            color: isSelected
                                ? AppColors.deepCharcoal
                                : Colors.white30)
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // 3. Generate Button
        if (state.isLoading)
          const Center(
              child: CircularProgressIndicator(color: AppColors.zestyLime))
        else
          SizedBox(
              width: double.infinity,
              child: HapticButton(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  final pantryState = ref.read(pantryControllerProvider);

                  if (pantryState.hasError) {
                    if (NetworkErrorView.isNetworkError(pantryState.error!)) {
                      NanoToast.showError(context,
                          AppLocalizations.of(context)!.errorNoConnection);
                    } else {
                      NanoToast.showError(
                          context, AppLocalizations.of(context)!.errorGeneric);
                    }
                    return;
                  }

                  final pantryItems = pantryState.valueOrNull ?? [];
                  if (pantryItems.isEmpty) {
                    toastification.show(
                      context: context,
                      type: ToastificationType.warning,
                      style: ToastificationStyle.flat,
                      title: Text(AppLocalizations.of(context)!
                          .generatorPantryEmptyTitle),
                      description: Text(AppLocalizations.of(context)!
                          .generatorPantryEmptyDesc),
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: const Duration(seconds: 4),
                      backgroundColor: AppColors.deepCharcoal,
                      primaryColor: AppColors.zestyLime,
                      foregroundColor: Colors.white,
                      showProgressBar: false,
                      icon:
                          const Icon(Icons.kitchen, color: AppColors.zestyLime),
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.zestyLime),
                    );
                    return;
                  }

                  final subState = ref.read(subscriptionControllerProvider);
                  final isPremium =
                      subState.valueOrNull != SubscriptionTier.homeCook;

                  // Trigger Generation with Unified Options
                  ref.read(recipeControllerProvider.notifier).generate(
                        mode: 'pantry_chef',
                        mealType: options.mealType,
                        mood: options.mood,
                        filters: options.filters,
                        allergies: options.allergies,
                        cuisine: options.cuisine,
                        maxTime: options.maxTime,
                        skillLevel: options.skillLevel,
                        includeGlobalDiet:
                            isPremium && widget.applyDietaryProfile,
                      );

                  widget.onGenerate();
                },
                label: AppLocalizations.of(context)!.generatorGenerateRecipes,
                icon: Icons.auto_awesome,
              )),
      ],
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
