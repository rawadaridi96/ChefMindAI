import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'shopping_repository.g.dart';

@riverpod
ShoppingRepository shoppingRepository(ShoppingRepositoryRef ref) {
  return ShoppingRepository(Supabase.instance.client);
}

class ShoppingRepository {
  final SupabaseClient _client;

  ShoppingRepository(this._client);

  Future<List<Map<String, dynamic>>> getItems() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('shopping_cart')
        .select()
        .eq('user_id', userId) // Explicit data isolation
        .order('is_bought', ascending: true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addItem(String name, String amount, String category,
      {String? recipeSource}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Temporary fix: 'recipe_source' column missing in DB.
    final data = {
      'user_id': userId,
      'item_name': name,
      'amount': amount,
      'category': category,
      'is_bought': false,
    };
    if (recipeSource != null) {
      data['recipe_source'] = recipeSource;
    }

    await _client.from('shopping_cart').insert(data);
  }

  Future<void> updateAmount(int id, String newAmount) async {
    await _client
        .from('shopping_cart')
        .update({'amount': newAmount}).eq('id', id);
  }

  Future<void> updateAmountAndSource(int id, String newAmount,
      {String? newSource}) async {
    final Map<String, dynamic> updates = {'amount': newAmount};
    if (newSource != null) {
      updates['recipe_source'] = newSource;
    }
    await _client.from('shopping_cart').update(updates).eq('id', id);
  }

  Future<void> toggleStatus(int id, bool isBought) async {
    await _client
        .from('shopping_cart')
        .update({'is_bought': isBought}).eq('id', id);
  }

  Future<void> deleteItem(int id) async {
    await _client.from('shopping_cart').delete().eq('id', id);
  }

  Future<void> clearBoughtItems() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('shopping_cart')
        .delete()
        .eq('user_id', userId)
        .eq('is_bought', true);
  }

  Future<void> clearAllItems() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('shopping_cart').delete().eq('user_id', userId);
  }
}
