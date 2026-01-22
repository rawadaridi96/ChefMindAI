import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/pantry_repository.dart';
import '../../../core/services/offline_manager.dart';

part 'pantry_controller.g.dart';

@riverpod
class PantryController extends _$PantryController {
  @override
  Stream<List<Map<String, dynamic>>> build() {
    // Return Local Stream (Offline First)
    return ref.read(pantryRepositoryProvider).watchPantryItems();
  }

  Future<void> refresh() async {
    await ref.read(pantryRepositoryProvider).syncPantryItems();
  }

  Future<int> addIngredients(List<String> ingredients) async {
    final currentItems = state.value ?? [];

    // Normalize existing names for comparison
    final existingNames = currentItems
        .map((item) => (item['name'] as String).toLowerCase())
        .toSet();

    // Filter out duplicates
    final newIngredients = ingredients.where((name) {
      return !existingNames.contains(name.toLowerCase());
    }).toList();

    if (newIngredients.isEmpty) return 0;

    await _performOfflineSafe(() => ref
        .read(pantryRepositoryProvider)
        .addIngredients_Batch(newIngredients));

    return newIngredients.length;
  }

  Future<bool> addIngredient(String name, String category) async {
    final currentItems = state.value ?? [];

    final exists = currentItems.any(
        (item) => (item['name'] as String).toLowerCase() == name.toLowerCase());

    if (exists) return false;

    await _performOfflineSafe(
        () => ref.read(pantryRepositoryProvider).addIngredient(name, category));

    return true;
  }

  Future<void> deleteIngredient(String id) async {
    await _performOfflineSafe(
        () => ref.read(pantryRepositoryProvider).deleteItem(id));
  }

  Future<void> _performOfflineSafe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      final isConnected = ref.read(offlineManagerProvider).hasConnection;
      if (!isConnected) {
        // Swallow error - Optimistic Update already happened in Repo
        return;
      }
      rethrow;
    }
  }
}
