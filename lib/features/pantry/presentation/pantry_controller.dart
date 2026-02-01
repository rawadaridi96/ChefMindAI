import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/pantry_repository.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/pexels_service.dart';
import '../../auth/presentation/auth_state_provider.dart';
import 'dart:math';

part 'pantry_controller.g.dart';

@riverpod
class PantryController extends _$PantryController {
  @override
  Stream<List<Map<String, dynamic>>> build() {
    // Listen to auth state changes and sync when user signs in
    ref.listen(authStateChangesProvider, (previous, next) {
      next.whenData((authState) {
        if (authState.event == AuthChangeEvent.signedIn) {
          // User just signed in - sync pantry from remote
          Future.microtask(() => refresh());
        }
      });
    });

    // Trigger initial sync if user is already logged in
    final currentAuth = ref.read(authStateChangesProvider);
    if (currentAuth.hasValue && currentAuth.value?.session != null) {
      Future.microtask(() => refresh());
    }

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

    // Filter out duplicates (Simpler exact match set for quick lookup, but we need Fuzzy)
    final existingItems = currentItems
        .map((item) => (item['name'] as String).toLowerCase())
        .toList();

    final newIngredients = <String>[];
    for (final name in ingredients) {
      if (!_existsFuzzy(name, existingItems)) {
        newIngredients.add(name);
      }
    }

    if (newIngredients.isEmpty) return 0;

    await _performOfflineSafe(() => ref
        .read(pantryRepositoryProvider)
        .addIngredients_Batch(newIngredients));

    Future.delayed(const Duration(milliseconds: 500), () => refreshImages());

    return newIngredients.length;
  }

  Future<bool> addIngredient(String name, String category) async {
    final currentItems = state.value ?? [];

    // Check fuzzy existence
    final existingItems = currentItems
        .map((item) => (item['name'] as String).toLowerCase())
        .toList();

    if (_existsFuzzy(name, existingItems)) return false;

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

  /// Returns true if [name] is similar enough to any item in [existingList]
  bool _existsFuzzy(String name, List<String> existingList) {
    final lowerName = name.toLowerCase();
    for (final existing in existingList) {
      if (lowerName == existing) return true; // Exact match

      // Fuzzy Logic
      // 1. Length check: Must be remarkably similar in length (allow +/- 2 chars)
      if ((lowerName.length - existing.length).abs() > 2) continue;

      // 2. Short word safety: If < 5 chars, require exact match (e.g. "corn" != "pork")
      if (lowerName.length < 5 || existing.length < 5) continue;

      // 3. Substring strictness: "Peanut" vs "Peanut Butter"
      // If one is a substring of another but length diff > 2, treat distinct.
      // (Handled by length check above: 13 - 6 = 7 > 2 -> distinct)

      final dist = _levenshtein(lowerName, existing);
      final maxLength = max(lowerName.length, existing.length);

      // Threshold:
      // Distance <= 2 (allows 1-2 typos)
      // AND Ratio < 0.3 (ensures "long string" similarity)
      // E.g. "Choclate" (8) vs "Chocolate" (9). Dist=1. Ratio=0.11. OK.
      if (dist <= 2 && (dist / maxLength) < 0.3) {
        return true;
      }
    }
    return false;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
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
