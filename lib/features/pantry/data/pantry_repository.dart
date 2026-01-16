import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'pantry_repository.g.dart';

@riverpod
PantryRepository pantryRepository(PantryRepositoryRef ref) {
  return PantryRepository(Supabase.instance.client);
}

class PantryRepository {
  final SupabaseClient _client;

  PantryRepository(this._client);

  Future<List<Map<String, dynamic>>> getPantryItems() async {
    final response = await _client
        .from('pantry_items')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addIngredients_Batch(List<String> ingredients) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final data = ingredients
        .map((name) => {
              'user_id': userId,
              'name': name,
              'category': 'Uncategorized', // Default
            })
        .toList();

    await _client.from('pantry_items').upsert(data);
  }

  Future<void> addIngredient(String name, String category) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('pantry_items').upsert({
      'user_id': userId,
      'name': name,
      'category': category,
    });
  }

  Future<void> deleteItem(String id) async {
    await _client.from('pantry_items').delete().eq('id', id);
  }
}
