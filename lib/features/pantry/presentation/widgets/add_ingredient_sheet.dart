import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/haptic_button.dart';
import '../pantry_controller.dart';

class AddIngredientSheet extends ConsumerStatefulWidget {
  const AddIngredientSheet({super.key});

  @override
  ConsumerState<AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<AddIngredientSheet> {
  final _nameController = TextEditingController();
  String _selectedCategory = 'Produce';
  final List<String> _categories = [
    'Produce',
    'Proteins',
    'Dairy',
    'Grains',
    'Spices',
    'Beverages',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    ref
        .read(pantryControllerProvider.notifier)
        .addIngredient(name, _selectedCategory);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Add Item',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Name Input
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ingredient Name (e.g. Avocado)',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                icon: Icon(Icons.edit, color: AppColors.zestyLime),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),

          const SizedBox(height: 16),

          // Category Dropdown
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: AppColors.surfaceDark,
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppColors.zestyLime),
                isExpanded: true,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 32),

          HapticButton(
            onTap: _save,
            label: 'Add to Pantry',
            icon: Icons.add_circle_outline,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}
