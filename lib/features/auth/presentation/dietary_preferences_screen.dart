import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/haptic_button.dart';
import 'package:chefmind_ai/features/auth/data/auth_repository.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_controller.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';

class DietaryPreferencesScreen extends ConsumerStatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  ConsumerState<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState
    extends ConsumerState<DietaryPreferencesScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // State for all 4 categories
  final Set<String> _selectedPreferences = {};

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Food Allergies',
      'subtitle': 'Select any immune-system exclusions (The "Big 9").',
      'items': [
        {'name': 'Peanuts', 'icon': Icons.grass},
        {'name': 'Tree Nuts', 'icon': Icons.nature},
        {'name': 'Eggs', 'icon': Icons.egg},
        {'name': 'Fish', 'icon': Icons.phishing},
        {'name': 'Shellfish', 'icon': Icons.set_meal},
        {'name': 'Milk', 'icon': Icons.local_drink}, // Dairy allergy
        {'name': 'Soy', 'icon': Icons.eco},
        {'name': 'Wheat', 'icon': Icons.bakery_dining},
        {'name': 'Sesame', 'icon': Icons.grain},
      ]
    },
    {
      'title': 'Intolerances',
      'subtitle': 'Digestive sensitivities to avoid.',
      'items': [
        {'name': 'Lactose Intolerant', 'icon': Icons.no_drinks},
        {'name': 'Gluten Intolerant', 'icon': Icons.do_not_touch},
        {'name': 'Fructose', 'icon': Icons.emoji_food_beverage},
        {'name': 'Histamine', 'icon': Icons.warning_amber},
      ]
    },
    {
      'title': 'Lifestyle & Beliefs',
      'subtitle': 'Choices based on ethics, religion, or preference.',
      'items': [
        {'name': 'Vegetarian', 'icon': Icons.cruelty_free},
        {'name': 'Vegan', 'icon': Icons.spa},
        {'name': 'Pescatarian', 'icon': Icons.water},
        {'name': 'Halal', 'icon': Icons.mosque},
        {'name': 'Kosher', 'icon': Icons.star},
      ]
    },
    {
      'title': 'Health Goals',
      'subtitle': 'Nutritional focuses for your meals.',
      'items': [
        {'name': 'Keto', 'icon': Icons.monitor_weight},
        {'name': 'Paleo', 'icon': Icons.terrain},
        {'name': 'Low-Carb', 'icon': Icons.fitness_center},
        {'name': 'Low-Sodium', 'icon': Icons.favorite},
        {'name': 'Diabetic-Friendly', 'icon': Icons.bloodtype},
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      final prefs = user.userMetadata?['dietary_preferences'];
      if (prefs != null && prefs is List) {
        setState(() {
          _selectedPreferences.addAll(prefs.map((e) => e.toString()));
        });
      }
    }
  }

  void _togglePreference(String name) {
    setState(() {
      if (_selectedPreferences.contains(name)) {
        _selectedPreferences.remove(name);
      } else {
        _selectedPreferences.add(name);
      }
      HapticFeedback.lightImpact();
    });
  }

  void _clearAll() {
    setState(() {
      _selectedPreferences.clear();
      HapticFeedback.mediumImpact();
    });
    NanoToast.showInfo(context, "All preferences cleared");
  }

  void _nextPage() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _finish() async {
    // Save to backend
    await ref
        .read(authControllerProvider.notifier)
        .updateDietaryPreferences(_selectedPreferences.toList());

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    final double progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Back + Progress)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white70),
                        onPressed: _previousPage,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.zestyLime,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        "${_currentStep + 1} / ${_steps.length}",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearAll,
                        child: const Text("Clear All",
                            style: TextStyle(
                                color: AppColors.errorRed, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swipe
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      final items = step['items'] as List<Map<String, dynamic>>;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'],
                              style: const TextStyle(
                                color: AppColors.zestyLime,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              step['subtitle'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 32),
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
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final item = items[i];
                                final isSelected =
                                    _selectedPreferences.contains(item['name']);
                                return GestureDetector(
                                  onTap: () => _togglePreference(item['name']),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.zestyLime
                                              .withOpacity(0.15)
                                          : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.zestyLime
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item['icon'],
                                          size: 40,
                                          color: isSelected
                                              ? AppColors.zestyLime
                                              : Colors.white70,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          item['name'],
                                          textAlign: TextAlign.center,
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
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Step Button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.deepCharcoal,
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: HapticButton(
                      label: _currentStep == _steps.length - 1
                          ? 'Finish & Save'
                          : 'Next',
                      onTap: _nextPage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
