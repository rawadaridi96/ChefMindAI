import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/pantry_repository.dart';

part 'pantry_controller.g.dart';

@riverpod
class PantryController extends _$PantryController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return ref.read(pantryRepositoryProvider).getPantryItems();
  }

  Future<void> addIngredients(List<String> ingredients) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(pantryRepositoryProvider)
          .addIngredients_Batch(ingredients);
      return ref.read(pantryRepositoryProvider).getPantryItems();
    });
  }

  Future<void> addIngredient(String name, String category) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(pantryRepositoryProvider).addIngredient(name, category);
      return ref.read(pantryRepositoryProvider).getPantryItems();
    });
  }

  Future<void> deleteIngredient(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(pantryRepositoryProvider).deleteItem(id);
      return ref.read(pantryRepositoryProvider).getPantryItems();
    });
  }
}
