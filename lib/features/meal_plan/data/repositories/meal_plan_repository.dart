import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/offline_manager.dart';
import '../../../../core/services/sync_queue_service.dart';
import '../models/meal_plan_model.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(
    Supabase.instance.client,
    ref.read(syncQueueServiceProvider),
    ref.read(offlineManagerProvider),
  );
});

class MealPlanRepository {
  static const String boxName = 'meal_plan_box';
  static const String tableName = 'meal_plans';

  final SupabaseClient _client;
  final SyncQueueService _syncQueueService;
  final OfflineManager _offlineManager;

  MealPlanRepository(
      this._client, this._syncQueueService, this._offlineManager);

  Future<Box<MealPlanModel>> _openBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<MealPlanModel>(boxName);
    }
    return Hive.box<MealPlanModel>(boxName);
  }

  Future<void> saveMeal(MealPlanModel meal) async {
    // 1. Save Local (Hive) - Optimistic
    final box = await _openBox();
    await box.put(meal.id, meal);

    // 2. Sync to Cloud
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // Local only if not logged in

    // Ensure model has userId (if not already set)
    final mealWithUser = MealPlanModel(
      id: meal.id,
      date: meal.date,
      mealType: meal.mealType,
      recipeId: meal.recipeId,
      customDescription: meal.customDescription,
      recipeTitle: meal.recipeTitle,
      userId: userId,
    );
    // Update Hive again with userId just in case
    await box.put(meal.id, mealWithUser);

    final payload = mealWithUser.toJson();

    if (!_offlineManager.hasConnection) {
      await _syncQueueService.queueOperation(tableName, 'upsert', payload);
      return;
    }

    try {
      await _client.from(tableName).upsert(payload);
    } catch (_) {
      // Fallback to queue if request fails
      await _syncQueueService.queueOperation(tableName, 'upsert', payload);
    }
  }

  Future<void> deleteMeal(String id) async {
    // 1. Delete Local - Optimistic
    final box = await _openBox();
    await box.delete(id);

    // 2. Sync to Cloud
    if (!_offlineManager.hasConnection) {
      await _syncQueueService.queueOperation(tableName, 'delete', {'id': id});
      return;
    }

    try {
      await _client.from(tableName).delete().eq('id', id);
    } catch (_) {
      await _syncQueueService.queueOperation(tableName, 'delete', {'id': id});
    }
  }

  // Sync: Pull remote changes and merge
  Future<void> syncMealPlans() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Fetch Remote
      final response = await _client.from(tableName).select();
      final remoteList = List<Map<String, dynamic>>.from(response);

      // 2. Merge into Hive
      final box = await _openBox();
      for (final json in remoteList) {
        final remoteMeal = MealPlanModel.fromJson(json);
        await box.put(remoteMeal.id, remoteMeal);
      }

      // Note: We don't delete local items that are missing from remote here,
      // because that would delete unsynced local creations. True 2-way sync
      // requires "deleted_at" flags or more complex logic.
      // For now, "Push Local -> Queue" and "Pull Remote -> Upsert" covers 95% cases.
    } catch (e) {
      print("MealPlan Sync Failed: $e");
    }
  }

  Future<List<MealPlanModel>> getMealsForWeek(DateTime startOfWeek) async {
    final box = await _openBox();
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return box.values.where((meal) {
      return meal.date
              .isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          meal.date.isBefore(endOfWeek);
    }).toList();
  }

  Future<List<MealPlanModel>> getAllMeals() async {
    final box = await _openBox();
    return box.values.toList();
  }
}
