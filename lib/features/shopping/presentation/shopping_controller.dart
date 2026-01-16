import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/shopping_repository.dart';

part 'shopping_controller.g.dart';

@riverpod
class ShoppingController extends _$ShoppingController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return ref.read(shoppingRepositoryProvider).getItems();
  }

  Future<void> addItem(String name,
      {String amount = '1', String category = 'General'}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(shoppingRepositoryProvider)
          .addItem(name, amount, category);
      return ref.read(shoppingRepositoryProvider).getItems();
    });
  }

  Future<void> toggleItem(int id, bool currentValue) async {
    // Optimistic update could happen here, but standard reload for safety
    state = await AsyncValue.guard(() async {
      await ref
          .read(shoppingRepositoryProvider)
          .toggleStatus(id, !currentValue);
      return ref.read(shoppingRepositoryProvider).getItems();
    });
  }

  Future<void> deleteItem(int id) async {
    state = await AsyncValue.guard(() async {
      await ref.read(shoppingRepositoryProvider).deleteItem(id);
      return ref.read(shoppingRepositoryProvider).getItems();
    });
  }
}
