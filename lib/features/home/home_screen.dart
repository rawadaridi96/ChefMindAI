import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/nano_toast.dart';
import '../auth/presentation/auth_controller.dart';
import '../auth/data/auth_repository.dart';

import '../scanner/presentation/scanner_screen.dart';
import '../pantry/presentation/pantry_screen.dart';
import '../recipes/presentation/recipes_screen.dart';
import '../recipes/presentation/recipe_controller.dart';
import '../subscription/presentation/subscription_screen.dart';
import '../shopping/presentation/shopping_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../subscription/presentation/subscription_controller.dart';
import '../../core/widgets/premium_paywall.dart';
import '../../core/widgets/glass_container.dart';

import 'widgets/pulse_microphone_button.dart';

import '../recipes/presentation/widgets/pantry_generator_widget.dart';
import 'presentation/history_controller.dart';
import 'dart:ui'; // For ImageFilter
import '../meal_plan/presentation/meal_plan_provider.dart';
import '../meal_plan/presentation/meal_plan_screen.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/widgets/onboarding_overlay.dart';
import '../../features/guide/presentation/master_guide_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 2; // Default to Chef (center)
  final TextEditingController _searchController = TextEditingController();

  // Onboarding state
  bool _showOnboarding = false;
  bool _onboardingChecked = false;

  // GlobalKeys for onboarding targets
  final GlobalKey _modeToggleKey = GlobalKey();
  final GlobalKey _myPantryTabKey = GlobalKey(); // My Pantry side of toggle
  final GlobalKey _promptInputKey = GlobalKey();
  final GlobalKey _generateButtonKey = GlobalKey();
  final GlobalKey _dietaryToggleKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();

  // Pantry mode onboarding keys
  final GlobalKey _pantryFilterKey = GlobalKey();
  final GlobalKey _pantrySelectorKey = GlobalKey();
  final GlobalKey _pantryGenerateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Check for post-login message (e.g. "Welcome back")
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final msg = ref.read(postLoginMessageProvider);
      if (msg != null && mounted) {
        String message = '';
        final l10n = AppLocalizations.of(context)!;
        switch (msg.key) {
          case 'authWelcomeBack':
            message = l10n.authWelcomeBack(msg.args.first);
            break;
          case 'authAccountCreated':
            message = l10n.authAccountCreated;
            break;
          case 'authWelcomeGuest':
            message = l10n.authWelcomeGuest;
            break;
          case 'authSignedInGoogle':
            message = l10n.authSignedInGoogle;
            break;
          case 'authSignedInApple':
            message = l10n.authSignedInApple;
            break;
          default:
            message = msg.key;
        }
        NanoToast.showSuccess(context, message);
        // Clear it so it doesn't show again on hot reload or re-mount
        ref.read(postLoginMessageProvider.notifier).state = null;
      }

      // Default Dietary Profile for Executive Chef
      final subState = ref.read(subscriptionControllerProvider);
      if (subState.valueOrNull == SubscriptionTier.executiveChef) {
        setState(() => _applyDietaryProfile = true);
      }

      // Check if onboarding should be shown
      if (!_onboardingChecked) {
        _onboardingChecked = true;
        final onboardingService = ref.read(onboardingServiceProvider);
        final shouldShow = await onboardingService.shouldShowOnboarding();
        if (shouldShow && mounted) {
          // Small delay to ensure UI is fully built
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            setState(() => _showOnboarding = true);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthMessage?>(postLoginMessageProvider, (previous, next) {
      if (next != null) {
        String message = '';
        final l10n = AppLocalizations.of(context)!;
        switch (next.key) {
          case 'authWelcomeBack':
            message = l10n.authWelcomeBack(next.args.first);
            break;
          case 'authAccountCreated':
            message = l10n.authAccountCreated;
            break;
          case 'authWelcomeGuest':
            message = l10n.authWelcomeGuest;
            break;
          case 'authSignedInGoogle':
            message = l10n.authSignedInGoogle;
            break;
          case 'authSignedInApple':
            message = l10n.authSignedInApple;
            break;
          default:
            message = next.key;
        }
        NanoToast.showSuccess(context, message);
        // Clear it so it doesn't show again on hot reload or re-mount
        ref.read(postLoginMessageProvider.notifier).state = null;
      }
    });

    final mealPlanEnabled = ref.watch(mealPlanEnabledProvider);

    // Screens ordered: Pantry, Recipes, Chef (center), (MealPlan optional), Cart
    // For index mapping: without meal plan: 0=Pantry, 1=Recipes, 2=Chef, 3=Cart
    // With meal plan: 0=Pantry, 1=MealPlan, 2=Chef, 3=Recipes, 4=Cart
    final List<Widget> screens = mealPlanEnabled
        ? [
            const PantryScreen(),
            const MealPlanScreen(),
            _buildHomeDashboard(ref), // Chef in center
            const RecipesScreen(),
            const ShoppingScreen(),
          ]
        : [
            const PantryScreen(),
            const RecipesScreen(),
            _buildHomeDashboard(ref), // Chef in center
            const ShoppingScreen(),
          ];

    // Calculate center index
    final int centerIndex = mealPlanEnabled ? 2 : 2;

    // Safety check for index
    if (_currentIndex >= screens.length) {
      _currentIndex = centerIndex; // Default to Chef
    }

    final l10n = AppLocalizations.of(context)!;

    // Define onboarding steps
    final onboardingSteps = [
      // Step 1: Explain the mode toggle with both options
      OnboardingStep(
        title: l10n.onboardingStepModeTitle,
        description: l10n.onboardingStepModeDesc,
        targetKey: _modeToggleKey,
        position: TooltipPosition.bottom,
      ),
      // Step 2: Prompt input (for Discover mode)
      OnboardingStep(
        title: l10n.onboardingStepPromptTitle,
        description: l10n.onboardingStepPromptDesc,
        targetKey: _promptInputKey,
        position: TooltipPosition.bottom,
      ),
      // Step 3: Dietary toggle
      OnboardingStep(
        title: l10n.onboardingStepDietaryTitle,
        description: l10n.onboardingStepDietaryDesc,
        targetKey: _dietaryToggleKey,
        position: TooltipPosition.bottom,
      ),
      // Step 4: Generate button (Discover)
      OnboardingStep(
        title: l10n.onboardingStepGenerateTitle,
        description: l10n.onboardingStepGenerateDesc,
        targetKey: _generateButtonKey,
        position: TooltipPosition.top,
      ),
      // Step 5: Interactive step - Tap My Pantry to switch modes
      OnboardingStep(
        title: l10n.onboardingStepPantryTitle,
        description: l10n.onboardingStepPantryDesc,
        targetKey: _myPantryTabKey,
        position:
            TooltipPosition.bottom, // Position below with gap to avoid masking
        requiresAction: true,
        actionLabel: 'Tap My Pantry',
        onAction: () => setState(() => _isPantryMode = true),
      ),
      // Step 6: Pantry mode - Filter button
      OnboardingStep(
        title: l10n.onboardingStepPantryFilterTitle,
        description: l10n.onboardingStepPantryFilterDesc,
        targetKey: _pantryFilterKey,
        position: TooltipPosition.bottom,
      ),
      // Step 7: Pantry mode - Selectors (Meal Type, Vibe)
      OnboardingStep(
        title: l10n.onboardingStepPantrySelectorTitle,
        description: l10n.onboardingStepPantrySelectorDesc,
        targetKey: _pantrySelectorKey,
        position: TooltipPosition.bottom,
      ),
      // Step 8: Pantry mode - Generate button
      OnboardingStep(
        title: l10n.onboardingStepPantryGenerateTitle,
        description: l10n.onboardingStepPantryGenerateDesc,
        targetKey: _pantryGenerateKey,
        position: TooltipPosition.top,
      ),
      // Step 9: Bottom navigation
      OnboardingStep(
        title: l10n.onboardingStepNavTitle,
        description: l10n.onboardingStepNavDesc,
        targetKey: _bottomNavKey,
        position: TooltipPosition.top,
      ),
    ];

    return Stack(
      children: [
        Scaffold(
          body: Stack(
            children: [
              // Global Background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.deepCharcoal, Color(0xFF202020)],
                  ),
                ),
              ),
              SafeArea(
                child: IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
              ),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: Container(
            key: _bottomNavKey,
            child: _buildCurvedBottomNav(mealPlanEnabled, centerIndex),
          ),
          floatingActionButton: _currentIndex == centerIndex
              ? FloatingActionButton(
                  backgroundColor: AppColors.zestyLime,
                  heroTag: 'home_scan_fab',
                  child: const Icon(Icons.camera_alt,
                      color: AppColors.deepCharcoal),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerScreen()),
                    );
                  },
                )
              : null,
        ),
        // Onboarding overlay
        if (_showOnboarding)
          OnboardingOverlay(
            steps: onboardingSteps,
            onComplete: () async {
              final onboardingService = ref.read(onboardingServiceProvider);
              await onboardingService.completeOnboarding();
              if (mounted) setState(() => _showOnboarding = false);
            },
            onSkip: () async {
              final onboardingService = ref.read(onboardingServiceProvider);
              await onboardingService.completeOnboarding();
              if (mounted) setState(() => _showOnboarding = false);
            },
            onDontShowAgainChanged: (value) async {
              final onboardingService = ref.read(onboardingServiceProvider);
              await onboardingService.setDontShowAgain(value);
            },
          ),
      ],
    );
  }

  Widget _buildCurvedBottomNav(bool mealPlanEnabled, int centerIndex) {
    // Nav items config: icon, label, index
    final List<_NavItemData> navItemsConfig = mealPlanEnabled
        ? [
            _NavItemData(
                Icons.kitchen, AppLocalizations.of(context)!.navPantry, 0),
            _NavItemData(Icons.calendar_month, "Meal Plan", 1),
            _NavItemData(Icons.restaurant_menu,
                AppLocalizations.of(context)!.navChef, 2), // Chef in center
            _NavItemData(
                Icons.menu_book, AppLocalizations.of(context)!.navRecipes, 3),
            _NavItemData(
                Icons.shopping_cart, AppLocalizations.of(context)!.navCart, 4),
          ]
        : [
            _NavItemData(
                Icons.kitchen, AppLocalizations.of(context)!.navPantry, 0),
            _NavItemData(
                Icons.menu_book, AppLocalizations.of(context)!.navRecipes, 1),
            _NavItemData(Icons.restaurant_menu,
                AppLocalizations.of(context)!.navChef, 2), // Chef in center
            _NavItemData(
                Icons.shopping_cart, AppLocalizations.of(context)!.navCart, 3),
          ];

    // Build left and right nav items separately
    final leftItems =
        navItemsConfig.where((item) => item.index < centerIndex).toList();
    final rightItems =
        navItemsConfig.where((item) => item.index > centerIndex).toList();

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Main rounded bar
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.deepCharcoal,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left nav items
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: leftItems.map((item) {
                        final isSelected = _currentIndex == item.index;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _currentIndex = item.index),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected
                                      ? AppColors.zestyLime
                                      : Colors.white54,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.zestyLime
                                        : Colors.white54,
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Selection indicator dot
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.zestyLime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Space for center button
                  const SizedBox(width: 70),
                  // Right nav items
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: rightItems.map((item) {
                        final isSelected = _currentIndex == item.index;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _currentIndex = item.index),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected
                                      ? AppColors.zestyLime
                                      : Colors.white54,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.zestyLime
                                        : Colors.white54,
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Selection indicator dot
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.zestyLime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Center floating button (Chef)
          Positioned(
            bottom: 30,
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = centerIndex),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == centerIndex
                      ? AppColors.zestyLime
                      : AppColors.deepCharcoal,
                  border: Border.all(
                    color: _currentIndex == centerIndex
                        ? AppColors.zestyLime
                        : Colors.white30,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _currentIndex == centerIndex
                          ? AppColors.zestyLime.withOpacity(0.4)
                          : Colors.black45,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: _currentIndex == centerIndex
                      ? AppColors.deepCharcoal
                      : Colors.white54,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard(WidgetRef ref) {
    return Column(
      children: [
        AppBar(
          title: const BrandLogo(fontSize: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Streak System (Commented out for now)
            /*
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 4),
                  Text("3",
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            */

            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: () => _showHelpMenu(context),
            ),
            IconButton(
              icon: const Icon(Icons.diamond_outlined,
                  color: AppColors.zestyLime),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        Container(
          height: 1.0,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context)!.homePrompt,
                  style: const TextStyle(
                    color: AppColors.electricWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildSearchBar(ref),
              ],
            ),
          ),
        ),
        // _buildSkillBadges(), (Commented out for now)
      ],
    );
  }

  bool _isPantryMode = false; // Default: Discover Mode
  bool _applyDietaryProfile = false; // Default: Off for Discover Mode
  String? _mood;

  void _dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ... build method ...

  Widget _buildSearchBar(WidgetRef ref) {
    if (_isPantryMode) {
      return Column(
        children: [
          // Smart Toggle
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPantryMode = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isPantryMode
                            ? AppColors.zestyLime
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)!.homeDiscoverMode,
                        style: TextStyle(
                            color: !_isPantryMode
                                ? AppColors.deepCharcoal
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPantryMode = true),
                    child: Container(
                      key: _myPantryTabKey,
                      decoration: BoxDecoration(
                        color: _isPantryMode
                            ? AppColors.zestyLime
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)!.homePantryMode,
                        style: TextStyle(
                            color: _isPantryMode
                                ? AppColors.deepCharcoal
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // New Pantry Generator Widget
          PantryGeneratorWidget(
            applyDietaryProfile: _applyDietaryProfile,
            onDietaryChanged: (val) =>
                setState(() => _applyDietaryProfile = val),
            onGenerate: () {
              // Switch to Recipes tab after generation starts
              final mealPlanEnabled = ref.read(mealPlanEnabledProvider);
              setState(
                  () => _currentIndex = mealPlanEnabled ? 3 : 1); // Recipes tab
            },
            filterButtonKey: _pantryFilterKey,
            selectorGroupKey: _pantrySelectorKey,
            pantryGenerateKey: _pantryGenerateKey,
          ),
        ],
      );
    }

    return Column(
      children: [
        // Smart Toggle
        Container(
          key: _modeToggleKey,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPantryMode = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_isPantryMode
                          ? AppColors.zestyLime
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)!.homeDiscoverMode,
                      style: TextStyle(
                          color: !_isPantryMode
                              ? AppColors.deepCharcoal
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPantryMode = true),
                  child: Container(
                    key: _myPantryTabKey,
                    decoration: BoxDecoration(
                      color: _isPantryMode
                          ? AppColors.zestyLime
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)!.homePantryMode,
                      style: TextStyle(
                          color: _isPantryMode
                              ? AppColors.deepCharcoal
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Controls Row (Dietary Toggle + History)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dietary Toggle
              _buildDietaryToggle(ref),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mood Button
                  GestureDetector(
                    onTap: () => _showMoodSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _mood != null
                            ? AppColors.zestyLime.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _mood != null
                                ? AppColors.zestyLime
                                : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              _mood != null
                                  ? Icons.emoji_objects
                                  : Icons.emoji_objects_outlined,
                              size: 16,
                              color: _mood != null
                                  ? AppColors.zestyLime
                                  : Colors.white38),
                          if (_mood != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _mood!,
                              style: const TextStyle(
                                  color: AppColors.zestyLime,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // History Button
                  GestureDetector(
                    onTap: () => _showHistorySheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.history,
                          size: 16, color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Discover Search UI
        GlassContainer(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.zestyLime),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: _promptInputKey,
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.homeSearchHint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) => _performSearch(ref, value),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () => setState(() => _searchController.clear()),
                ),
              PulseMicrophoneButton(
                onResult: (text) {
                  setState(() {
                    _searchController.text = text;
                  });
                },
                onlisteningStart: () {},
                onListeningEnd: () {
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(ref, _searchController.text);
                  }
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: GestureDetector(
            key: _generateButtonKey,
            onTap: () => _performSearch(ref, _searchController.text),
            child: Container(
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
              child: Text(
                AppLocalizations.of(context)!.homeGenerateButton,
                style: const TextStyle(
                  color: AppColors.deepCharcoal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // _buildSkillBadges(), (Gamification disabled)
      ],
    );
  }

  void _performSearch(WidgetRef ref, String query) {
    if (query.trim().isEmpty) {
      NanoToast.showInfo(
          context, AppLocalizations.of(context)!.homeEmptyPrompt);
      return;
    }

    // Check Subscription for ADI
    final subState = ref.read(subscriptionControllerProvider);
    final isPremium = subState.valueOrNull != SubscriptionTier.homeCook;

    // Logic Branching
    if (_isPantryMode) {
      // Pantry Mode: Use pantry items + query context
      ref.read(recipeControllerProvider.notifier).generate(
            mode: 'pantry_chef',
            query: query,
            includeGlobalDiet: isPremium, // Only enable ADI if premium
          );
    } else {
      // Discover Mode: Pure generation
      ref.read(recipeControllerProvider.notifier).generate(
            mode: 'discover',
            query: query,
            includeGlobalDiet:
                _applyDietaryProfile, // Optional (UI handles lock)
            mood: _mood,
          );
    }

    // Save to History
    ref.read(historyControllerProvider.notifier).addPrompt(query);

    // Switch to Recipes tab
    final mealPlanEnabled = ref.read(mealPlanEnabledProvider);
    setState(() {
      _currentIndex = mealPlanEnabled ? 3 : 1; // Recipes tab
      _searchController.clear();
    });
  }

  Widget _buildSkillBadges() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Chef Skills",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBadgeItem("Sauce Master", Icons.waves, true),
              _buildBadgeItem("Bread Winner", Icons.bakery_dining, false),
              _buildBadgeItem("Grill Pro", Icons.outdoor_grill, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(String label, IconData icon, bool unlocked) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked
                ? AppColors.zestyLime.withOpacity(0.1)
                : Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(
                color: unlocked ? AppColors.zestyLime : Colors.white12),
          ),
          child: Icon(
            icon,
            color: unlocked ? AppColors.zestyLime : Colors.white24,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: unlocked ? Colors.white : Colors.white24,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showHistorySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F).withOpacity(0.8),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(24),
            child: Consumer(builder: (context, ref, child) {
              final historyAsync = ref.watch(historyControllerProvider);

              return historyAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white24)),
                error: (err, stack) => Center(
                    child: Text(
                        AppLocalizations.of(context)!.homeError(err.toString()),
                        style: const TextStyle(color: Colors.red))),
                data: (history) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.homeRecentIdeas,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          if (history.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                final backup = [...history];
                                ref
                                    .read(historyControllerProvider.notifier)
                                    .clearAll();
                                Navigator.pop(context); // Close sheet

                                // Show Undo SnackBar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF202020),
                                    content: Text(
                                        AppLocalizations.of(context)!
                                            .homeHistoryCleared,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    action: SnackBarAction(
                                      label: AppLocalizations.of(context)!
                                          .homeUndo,
                                      textColor: const Color(
                                          0xFFD1FF26), // AppColors.zestyLime
                                      onPressed: () {
                                        ref
                                            .read(historyControllerProvider
                                                .notifier)
                                            .restore(backup);
                                      },
                                    ),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.redAccent.withOpacity(0.8),
                              ),
                              child: Text(
                                  AppLocalizations.of(context)!.homeClearAll),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: history.isEmpty
                            ? const Center(
                                child: Text(
                                  "No recent history",
                                  style: TextStyle(color: Colors.white24),
                                ),
                              )
                            : ListView.separated(
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white10),
                                itemBuilder: (context, index) {
                                  final prompt = history[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.schedule,
                                        color: Colors.white38, size: 20),
                                    title: Text(
                                      prompt,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _searchController.text = prompt;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }

  final List<String> _moods = [
    'Comfort',
    'Date Night',
    'Quick & Easy',
    'Energetic',
    'Adventurous',
    'Fancy'
  ];

  String _getLocalizedMood(BuildContext context, String mood) {
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

  void _showMoodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.deepCharcoal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Consumer(
          builder: (context, ref, _) {
            final subscriptionState = ref.watch(subscriptionControllerProvider);
            final isExecutive =
                subscriptionState.valueOrNull == SubscriptionTier.executiveChef;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.homeSetMood,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    if (_mood != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _mood = null);
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context)!.homeClear,
                            style: const TextStyle(color: Colors.white54)),
                      )
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _moods.map((mood) {
                    final isSelected = _mood == mood;
                    return GestureDetector(
                      onTap: () {
                        if (!isExecutive) {
                          Navigator.pop(context); // Close sheet first
                          PremiumPaywall.show(context,
                              featureName: "Mood-Based Suggestions",
                              message:
                                  "Unlock precise mood-based cooking with Executive Chef.",
                              ctaLabel: "Upgrade to Executive Chef");
                          return;
                        }
                        setState(() {
                          if (isSelected) {
                            _mood = null;
                          } else {
                            _mood = mood;
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.zestyLime
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_getLocalizedMood(context, mood),
                                style: TextStyle(
                                    color: isSelected
                                        ? AppColors.deepCharcoal
                                        : Colors.white70,
                                    fontWeight: FontWeight.w600)),
                            if (!isExecutive) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.lock,
                                  size: 12,
                                  color: isSelected
                                      ? AppColors.deepCharcoal
                                      : Colors.white30)
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDietaryToggle(WidgetRef ref) {
    return Consumer(builder: (context, ref, _) {
      final user = ref.watch(authRepositoryProvider).currentUser;
      final subState = ref.watch(subscriptionControllerProvider);
      final tier = subState.valueOrNull ?? SubscriptionTier.homeCook;
      final isPremium = tier != SubscriptionTier.homeCook;

      final prefs = user?.userMetadata?['dietary_preferences'];
      final hasPreferences = prefs != null && prefs is List && prefs.isNotEmpty;

      final isEnabled = hasPreferences && isPremium;

      return Container(
        key: _dietaryToggleKey,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!isPremium) {
                    PremiumPaywall.show(context,
                        featureName:
                            AppLocalizations.of(context)!.premiumFeatureADI,
                        message: AppLocalizations.of(context)!.premiumADISous,
                        ctaLabel:
                            AppLocalizations.of(context)!.premiumUpgradeToSous);
                    return;
                  }
                  if (!hasPreferences) {
                    NanoToast.showInfo(
                        context, "Set your profile in Settings first 🧑‍🍳");
                    return;
                  }
                  setState(() => _applyDietaryProfile = !_applyDietaryProfile);
                },
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.homeDietaryProfile,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
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
                value: isEnabled && _applyDietaryProfile,
                activeColor: AppColors.zestyLime,
                activeTrackColor: AppColors.zestyLime.withOpacity(0.3),
                inactiveThumbColor: Colors.white54,
                inactiveTrackColor: Colors.white10,
                onChanged: (val) {
                  if (!isPremium) {
                    PremiumPaywall.show(context,
                        featureName:
                            AppLocalizations.of(context)!.premiumFeatureADI,
                        message: AppLocalizations.of(context)!.premiumADISous,
                        ctaLabel:
                            AppLocalizations.of(context)!.premiumUpgradeToSous);
                    return;
                  }
                  if (!hasPreferences) {
                    NanoToast.showInfo(
                        context, "Set your profile in Settings first 🧑‍🍳");
                    return;
                  }
                  setState(() => _applyDietaryProfile = val);
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showHelpMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.deepCharcoal,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: AppColors.zestyLime),
                const SizedBox(width: 12),
                Text(
                  "Need Help?",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tutorial Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.zestyLime.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.touch_app,
                    color: AppColors.zestyLime, size: 20),
              ),
              title: const Text("Start Interactive Tutorial",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Learn how to use the app step-by-step",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showOnboarding = true);
              },
            ),

            const Divider(color: Colors.white10),

            // Guide Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book,
                    color: Colors.blueAccent, size: 20),
              ),
              title: const Text("Values & Master Guide",
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text("Read detailed instructions & features",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MasterGuideScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Helper class for navigation item data
class _NavItemData {
  final IconData icon;
  final String label;
  final int index;

  _NavItemData(this.icon, this.label, this.index);
}

/// Custom clipper for the curved bottom navigation bar with valley/notch in center
class _CurvedNavClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double notchRadius = 38.0;
    final double notchDepth = 18.0;
    final double centerX = size.width / 2;

    // Start from top-left
    path.moveTo(0, notchDepth);

    // Draw left side going to center notch
    path.lineTo(centerX - notchRadius - 20, notchDepth);

    // Draw the curved notch (valley) using a quadratic bezier
    path.quadraticBezierTo(
      centerX - notchRadius, notchDepth, // control point
      centerX - notchRadius + 5, 0, // end of first curve
    );

    // Draw the bottom of the notch
    path.quadraticBezierTo(
      centerX, -notchDepth, // control point at center (dipping down)
      centerX + notchRadius - 5, 0, // end of valley bottom
    );

    // Draw right side of notch
    path.quadraticBezierTo(
      centerX + notchRadius, notchDepth, // control point
      centerX + notchRadius + 20, notchDepth, // end of curve
    );

    // Continue to right edge
    path.lineTo(size.width, notchDepth);

    // Draw right side down
    path.lineTo(size.width, size.height);

    // Draw bottom
    path.lineTo(0, size.height);

    // Close the path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
