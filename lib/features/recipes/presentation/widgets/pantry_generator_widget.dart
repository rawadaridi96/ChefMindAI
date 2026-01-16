import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/haptic_button.dart';
import 'package:chefmind_ai/features/recipes/presentation/recipe_controller.dart';
import 'package:chefmind_ai/features/pantry/presentation/pantry_controller.dart';
import 'package:toastification/toastification.dart';

class PantryGeneratorWidget extends ConsumerStatefulWidget {
  final VoidCallback onGenerate;

  const PantryGeneratorWidget({super.key, required this.onGenerate});

  @override
  ConsumerState<PantryGeneratorWidget> createState() =>
      _PantryGeneratorWidgetState();
}

class _PantryGeneratorWidgetState extends ConsumerState<PantryGeneratorWidget> {
  String _mealType = 'Dinner';
  final List<String> _selectedFilters = [];
  final TextEditingController _allergyController = TextEditingController();

  final List<String> _mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Dessert',
    'Snack'
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
      children: [
        // Context Selector (Meal Type) - Horizontal List
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _mealTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = _mealTypes[index];
              final isSelected = type == _mealType;
              return GestureDetector(
                onTap: () => setState(() => _mealType = type),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.zestyLime : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(type,
                      style: TextStyle(
                          color: isSelected
                              ? AppColors.deepCharcoal
                              : Colors.white70,
                          fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Filter Summary & Edit Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedFilters.isEmpty &&
                          _allergyController.text.isEmpty)
                        const Text("No extra filters",
                            style: TextStyle(
                                color: Colors.white30,
                                fontStyle: FontStyle.italic)),
                      ..._selectedFilters.map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                                label: Text(f),
                                backgroundColor: Colors.white10,
                                labelStyle: const TextStyle(
                                    fontSize: 12, color: Colors.white)),
                          )),
                      if (_allergyController.text.isNotEmpty)
                        Chip(
                            label:
                                Text("Restricted: ${_allergyController.text}"),
                            backgroundColor:
                                AppColors.errorRed.withOpacity(0.2),
                            labelStyle: const TextStyle(
                                fontSize: 12, color: AppColors.errorRed)),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _showFilterSheet,
                icon: const Icon(Icons.tune, color: AppColors.zestyLime),
              )
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Generate Button
        if (state.isLoading)
          const CircularProgressIndicator(color: AppColors.zestyLime)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: HapticButton(
              onTap: () {
                // Pantry Check
                final pantryItems =
                    ref.read(pantryControllerProvider).valueOrNull ?? [];
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

                // Trigger Generation
                ref.read(recipeControllerProvider.notifier).generate(
                      mode: 'pantry_chef',
                      filters: _selectedFilters,
                      mealType: _mealType,
                      allergies: _allergyController.text.isNotEmpty
                          ? _allergyController.text
                          : null,
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
