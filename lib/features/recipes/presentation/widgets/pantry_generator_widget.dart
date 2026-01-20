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
  String _mealType = 'Surprise Me';
  String? _mood;
  final List<String> _selectedFilters = [];
  final TextEditingController _allergyController = TextEditingController();

  final List<String> _mealTypes = [
    'Surprise Me',
    'Breakfast',
    'Main Meal',
    'Dessert',
    'Snack'
  ];

  final List<String> _moods = [
    'Comfort',
    'Date Night',
    'Quick & Easy',
    'Energetic',
    'Adventurous',
    'Fancy'
  ];

  final List<String> _availableFilters = [
    'Gourmet',
    'Healthy',
    '15-min',
    'Comfort',
    'Exotic',
    'Vegan',
    'Keto',
    'Low Carb',
    'High Protein'
  ];

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeControllerProvider);

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
                    final isSelected = type == _mealType;
                    return GestureDetector(
                      onTap: () => setState(() => _mealType = type),
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
                    color: (_selectedFilters.isNotEmpty ||
                            _allergyController.text.isNotEmpty)
                        ? AppColors.zestyLime.withOpacity(0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.tune,
                      size: 18,
                      color: (_selectedFilters.isNotEmpty ||
                              _allergyController.text.isNotEmpty)
                          ? AppColors.zestyLime
                          : Colors.white70),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Mood Selector (Compact & Integrated)
        SizedBox(
          height: 36, // Compact height
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _moods.length + 1, // +1 for "Vibe" label
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              // Leading Label
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
                          _mood == null ? "Vibe:" : "Vibe:",
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
              final isSelected = _mood == mood;
              final subscriptionState =
                  ref.watch(subscriptionControllerProvider);
              final isExecutive = subscriptionState.valueOrNull ==
                  SubscriptionTier.executiveChef;

              // Icons for moods
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
                    NanoToast.showError(
                        context, "Upgrade to Executive Chef to unlock Moods!");
                    return;
                  }
                  setState(() {
                    if (isSelected) {
                      _mood = null;
                    } else {
                      _mood = mood;
                    }
                  });
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
                      Text(mood,
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
                FocusScope.of(context).unfocus(); // Dismiss keyboard
                // Pantry Check
                final pantryState = ref.read(pantryControllerProvider);

                if (pantryState.hasError) {
                  if (NetworkErrorView.isNetworkError(pantryState.error!)) {
                    NanoToast.showError(
                        context, "No connection. Please check your internet.");
                  } else {
                    NanoToast.showError(
                        context, "Could not load pantry items.");
                  }
                  return;
                }

                final pantryItems = pantryState.valueOrNull ?? [];
                if (pantryItems.isEmpty) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.warning,
                    style: ToastificationStyle.flat,
                    title: const Text("Your pantry is empty!"),
                    description:
                        const Text("Please add items or use Global Search."),
                    alignment: Alignment.bottomCenter,
                    autoCloseDuration: const Duration(seconds: 4),
                    backgroundColor: AppColors.deepCharcoal,
                    primaryColor: AppColors.zestyLime,
                    foregroundColor: Colors.white,
                    showProgressBar: false,
                    icon: const Icon(Icons.kitchen, color: AppColors.zestyLime),
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.zestyLime),
                  );
                  return;
                }

                // Check Subscription
                final subState = ref.read(subscriptionControllerProvider);
                final isPremium =
                    subState.valueOrNull != SubscriptionTier.homeCook;

                // Trigger Generation
                ref.read(recipeControllerProvider.notifier).generate(
                      mode: 'pantry_chef',
                      filters: _selectedFilters,
                      mealType: _mealType,
                      mood: _mood,
                      allergies: _allergyController.text.isNotEmpty
                          ? _allergyController.text
                          : null,
                      includeGlobalDiet: isPremium &&
                          widget
                              .applyDietaryProfile, // Enable if premium AND toggled
                    );

                // Callback to navigate
                widget.onGenerate();
              },
              label: 'Generate Recipes',
              icon: Icons.auto_awesome,
            ),
          ),
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: 500,
            decoration: const BoxDecoration(
              color: AppColors.deepCharcoal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Filters & Diet",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Multi-select Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableFilters.map((filter) {
                    final isSelected = _selectedFilters.contains(filter);
                    return FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setSheetState(() {
                          if (selected) {
                            _selectedFilters.add(filter);
                          } else {
                            _selectedFilters.remove(filter);
                          }
                        });
                        setState(() {}); // Update parent
                      },
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

                // Allergies Input
                const Text("Allergies / Exclusions",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: _allergyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. No Nuts, Gluten Free',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),

                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal),
                    child: const Text("Done"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
