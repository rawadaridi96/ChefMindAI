import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/pantry_repository.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/pexels_service.dart';

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
    // Auto-Retry fetching images for items missing them
    refreshImages();
  }

  Future<void> refreshImages() async {
    final items = state.value ?? [];
    for (var item in items) {
      if (item['image_url'] == null || (item['image_url'] as String).isEmpty) {
        // Fetch in background
        PexelsService.searchImage(item['name'],
                orientation: 'landscape', suffix: 'food')
            .then((url) {
          if (url != null) {
            ref.read(pantryRepositoryProvider).updateImage(item['id'], url);
          }
        });
      }
    }
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

    // Note: Batch add doesn't support images easily yet without refactoring batch logic
    // We can iterate and fetch images for them separately if needed.
    // For now, let refreshImages() handle it on next load or explicitly call it?
    // Let's explicitly trigger it for these new items if we could know their IDs.
    // Since we don't know IDs for batch add easily (it returns void), we rely on refreshImages().
    // We can trigger refreshImages() after a short delay to allow Hive to populate?
    Future.delayed(const Duration(milliseconds: 500), () => refreshImages());

    return newIngredients.length;
  }

  Future<bool> addIngredient(String name, String category) async {
    final currentItems = state.value ?? [];

    final exists = currentItems.any(
        (item) => (item['name'] as String).toLowerCase() == name.toLowerCase());

    if (exists) return false;

    // 1. Add item immediately (no image yet)
    String id = '';
    await _performOfflineSafe(() async {
      id = await ref
          .read(pantryRepositoryProvider)
          .addIngredient(name, category);
    });

    // 2. Fire-and-forget image fetch
    if (id.isNotEmpty) {
      PexelsService.searchImage(name, orientation: 'landscape', suffix: 'food')
          .then((url) {
        if (url != null) {
          ref.read(pantryRepositoryProvider).updateImage(id, url);
        }
      });
    }

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
