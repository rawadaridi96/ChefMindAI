import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/haptic_button.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_controller.dart';

class DietaryPreferencesScreen extends ConsumerStatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  ConsumerState<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState
    extends ConsumerState<DietaryPreferencesScreen> {
  final Set<String> _selectedAllergens = {};

  final List<Map<String, dynamic>> _allergens = [
    {'name': 'Peanuts', 'icon': Icons.grass},
    {'name': 'Dairy', 'icon': Icons.local_drink},
    {'name': 'Shellfish', 'icon': Icons.set_meal},
    {'name': 'Eggs', 'icon': Icons.egg},
    {'name': 'Gluten', 'icon': Icons.bakery_dining},
    {'name': 'Soy', 'icon': Icons.eco},
    {'name': 'Fish', 'icon': Icons.phishing},
    {'name': 'Tree Nuts', 'icon': Icons.nature},
  ];

  void _toggleAllergen(String allergen) {
    setState(() {
      if (_selectedAllergens.contains(allergen)) {
        _selectedAllergens.remove(allergen);
      } else {
        _selectedAllergens.add(allergen);
      }
      HapticFeedback.lightImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF202020), AppColors.deepCharcoal],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Personalizing your\nAI Chef',
                    style: TextStyle(
                      color: AppColors.zestyLime,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select any allergies or ingredients you avoid.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _allergens.length,
                    itemBuilder: (context, index) {
                      final allergen = _allergens[index];
                      final isSelected =
                          _selectedAllergens.contains(allergen['name']);
                      return GestureDetector(
                        onTap: () => _toggleAllergen(allergen['name']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.zestyLime.withOpacity(0.15)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.zestyLime
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          AppColors.zestyLime.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allergen['icon'],
                                size: 40,
                                color: isSelected
                                    ? AppColors.zestyLime
                                    : Colors.white70,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allergen['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.zestyLime
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: HapticButton(
                      label: 'Continue',
                      onTap: () {
                        // Save preferences and navigate
                        ref
                            .read(authControllerProvider.notifier)
                            .updateDietaryPreferences(
                                _selectedAllergens.toList());
                        Navigator.pop(context); // Or navigate to Home
                      },
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Or navigate to Home
                      },
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
