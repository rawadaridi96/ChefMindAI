import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/meal_plan_model.dart';
import '../data/repositories/meal_plan_repository.dart';

final mealPlanControllerProvider =
    StateNotifierProvider<MealPlanController, AsyncValue<List<MealPlanModel>>>(
        (ref) {
  final repository = ref.watch(mealPlanRepositoryProvider);
  return MealPlanController(repository);
});

class MealPlanController
    extends StateNotifier<AsyncValue<List<MealPlanModel>>> {
  final MealPlanRepository _repository;

  MealPlanController(this._repository) : super(const AsyncValue.loading()) {
    loadAllMeals();
  }

  Future<void> loadAllMeals() async {
    try {
      // 1. Load Local (Instant)
      final localMeals = await _repository.getAllMeals();
      state = AsyncValue.data(localMeals);

      // 2. Background Sync (Cloud)
      await _repository.syncMealPlans();

      // 3. Refresh with potential new data
      final syncedMeals = await _repository.getAllMeals();
      // Only emit update if different? For now, simple re-emit is fine.
      state = AsyncValue.data(syncedMeals);
    } catch (e) {
      if (state.value == null) {
        state = AsyncValue.error(e, StackTrace.current);
      }
      // If we have local data, swallow sync error silently (offline mode)
    }
  }

  Future<void> addMealPlan({
    required DateTime date,
    required String mealType,
    String? recipeId,
    String? recipeTitle,
    String? customDescription,
  }) async {
    try {
      final newMeal = MealPlanModel(
        id: const Uuid().v4(),
        date: date,
        mealType: mealType,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        customDescription: customDescription,
      );

      await _repository.saveMeal(newMeal);

      // Reload or append locally
      final currentList = state.value ?? [];
      state = AsyncValue.data([...currentList, newMeal]);
    } catch (e) {
      // Handle error (maybe show toast in UI listener)
    }
  }

  Future<void> deleteMealPlan(String id) async {
    try {
      await _repository.deleteMeal(id);

      final currentList = state.value ?? [];
      state =
          AsyncValue.data(currentList.where((meal) => meal.id != id).toList());
    } catch (e) {
      // Handle error
    }
  }
}
