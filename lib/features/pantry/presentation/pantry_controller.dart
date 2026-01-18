import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/pantry_repository.dart';

part 'pantry_controller.g.dart';

@riverpod
class PantryController extends _$PantryController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return ref.read(pantryRepositoryProvider).getPantryItems();
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

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(pantryRepositoryProvider)
          .addIngredients_Batch(newIngredients);
      return ref.read(pantryRepositoryProvider).getPantryItems();
    });

    return newIngredients.length;
  }

  Future<bool> addIngredient(String name, String category) async {
    final currentItems = state.value ?? [];
    final exists = currentItems.any(
        (item) => (item['name'] as String).toLowerCase() == name.toLowerCase());

    if (exists) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(pantryRepositoryProvider).addIngredient(name, category);
      return ref.read(pantryRepositoryProvider).getPantryItems();
    });

    return true;
  }

  Future<void> deleteIngredient(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(pantryRepositoryProvider).deleteItem(id);
      return ref.read(pantryRepositoryProvider).getPantryItems();
    });
  }
}
