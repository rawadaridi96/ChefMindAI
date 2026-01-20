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

  Stream<List<Map<String, dynamic>>> getCartStream({String? householdId}) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    // Stream ALL allowed items (filtered by RLS) and filter client-side
    // This bypasses potential Realtime filter matching issues for INSERTS
    return _client
        .from('shopping_cart')
        .stream(primaryKey: ['id'])
        .order('is_bought', ascending: true)
        .order('created_at', ascending: false)
        .map((items) {
          if (householdId != null) {
            // Household Cart: Only items with matching household_id
            return items
                .where((i) => i['household_id'] == householdId)
                .toList();
          } else {
            // Personal Cart: Only items with NO household_id
            return items.where((i) => i['household_id'] == null).toList();
          }
        });
  }

  Future<void> addItem(String name, String amount, String category,
      {String? recipeSource, String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final data = {
      'user_id': userId,
      'item_name': name,
      'amount': amount,
      'category': category,
      'is_bought': false,
      if (householdId != null) 'household_id': householdId,
      if (recipeSource != null) 'recipe_source': recipeSource,
    };

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

  Future<void> clearBoughtItems({String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    var query = _client.from('shopping_cart').delete().eq('is_bought', true);

    if (householdId != null) {
      // Clear shared bought items
      await query.eq('household_id', householdId);
    } else {
      // Clear personal bought items
      await query.eq('user_id', userId).filter('household_id', 'is', 'null');
    }
  }

  Future<void> clearAllItems({String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    var query = _client.from('shopping_cart').delete();

    if (householdId != null) {
      await query.eq('household_id', householdId);
    } else {
      await query.eq('user_id', userId).filter('household_id', 'is', 'null');
    }
  }
}
