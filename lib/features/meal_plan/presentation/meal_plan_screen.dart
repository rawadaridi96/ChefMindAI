import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/nano_toast.dart';
import 'package:intl/intl.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'meal_plan_controller.dart';
import '../../recipes/data/vault_repository.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../../../core/widgets/premium_paywall.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final mealPlanAsync = ref.watch(mealPlanControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    final subState = ref.watch(subscriptionControllerProvider);
    final isFree = (subState.valueOrNull ?? SubscriptionTier.homeCook) ==
        SubscriptionTier.homeCook;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const BrandLogo(fontSize: 24),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: AppColors.zestyLime),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
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
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildMonthHeader(),
              _buildCalendarStrip(),
              const SizedBox(height: 16),
              Expanded(
                child: mealPlanAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.zestyLime)),
                  error: (err, stack) => Center(
                      child: Text(l10n.toastErrorGeneric(err.toString()),
                          style: const TextStyle(color: Colors.red))),
                  data: (allMeals) {
                    // Filter for selected date
                    final mealsForDate = allMeals
                        .where((m) => _isSameDay(m.date, _selectedDate))
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildMealSlot("Breakfast", l10n.mealTypeBreakfast,
                            Icons.wb_sunny_outlined, mealsForDate),
                        _buildMealSlot("Lunch", l10n.mealTypeLunch,
                            Icons.restaurant, mealsForDate),
                        _buildMealSlot("Dinner", l10n.mealTypeDinner,
                            Icons.nightlight_round, mealsForDate),
                        _buildMealSlot("Snacks", l10n.mealTypeSnacks,
                            Icons.cookie_outlined, mealsForDate),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (isFree)
            const Positioned.fill(
              child: PremiumPaywall(
                featureName: "Weekly Meal Planner",
                message:
                    "Plan your meals for the week. Add recipes to calendar slots and organize your shopping list.",
                ctaLabel: "Unlock Meal Planner",
                isDialog: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final startOfWeek =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final startStr = DateFormat('dd MMM yyyy').format(startOfWeek);
    final endStr = DateFormat('dd MMM yyyy').format(endOfWeek);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
            },
          ),
          Text(
            "$startStr - $endStr",
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip() {
    final now = DateTime.now();
    // Calculate start of the week (Monday) for the currently selected date
    // .weekday: Mon=1, Sun=7
    final startOfWeek =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    final dates =
        List.generate(7, (index) => startOfWeek.add(Duration(days: index)));

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, now);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.zestyLime : Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isToday ? AppColors.zestyLime : Colors.white12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? AppColors.deepCharcoal : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? AppColors.deepCharcoal : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealSlot(
      String id, String displayTitle, IconData icon, List<dynamic> allMeals) {
    // Filter by type using ID
    final meals = allMeals.where((m) => m.mealType == id).toList();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.zestyLime, size: 20),
                const SizedBox(width: 12),
                Text(
                  displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white54),
                  onPressed: () => _showRecipePicker(id, displayTitle),
                ),
              ],
            ),
          ),
          if (meals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n.mealPlanEmpty,
                  style: const TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: meals.map((meal) {
                return ListTile(
                  title: Text(
                    meal.recipeTitle ?? "Custom Meal",
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white30, size: 18),
                    onPressed: () {
                      ref
                          .read(mealPlanControllerProvider.notifier)
                          .deleteMealPlan(meal.id);
                      NanoToast.showSuccess(context, l10n.toastRemovedFromPlan);
                    },
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showRecipePicker(
      String mealTypeId, String mealTypeDisplay) async {
    // Fetch saved recipes
    final recipes = await ref.read(vaultRepositoryProvider).getSavedRecipes();

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.mealPlanAddTo(mealTypeDisplay),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: recipes.isEmpty
                    ? Center(
                        child: Text(
                          l10n.mealPlanNoRecipes,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: recipes.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              recipe['title'] ?? "Untitled",
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              "${recipe['total_calories'] ?? 0} kcal",
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: const Icon(Icons.add,
                                color: AppColors.zestyLime),
                            onTap: () {
                              ref
                                  .read(mealPlanControllerProvider.notifier)
                                  .addMealPlan(
                                    date: _selectedDate,
                                    mealType: mealTypeId,
                                    recipeId: recipe['id']
                                        .toString(), // Ensure string
                                    recipeTitle: recipe['title'],
                                  );
                              Navigator.pop(context);
                              NanoToast.showSuccess(
                                  context, l10n.toastAddedToMealPlan);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
