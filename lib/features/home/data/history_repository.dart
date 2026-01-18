import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Manual provider to avoid build_runner step for now
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(Supabase.instance.client);
});

class HistoryRepository {
  final SupabaseClient _client;

  HistoryRepository(this._client);

  Future<List<String>> fetchRecentPrompts() async {
    // Only get the top 5 for display, as per requirement
    final response = await _client
        .from('recent_prompts')
        .select('prompt')
        .order('created_at', ascending: false)
        .limit(5);

    final data = List<Map<String, dynamic>>.from(response);
    return data.map((e) => e['prompt'] as String).toList();
  }

  Future<void> addPrompt(String prompt) async {
    final user = _client.auth.currentUser;
    if (user == null) return; // Guard against no user

    // 1. Fetch existing prompts to check for duplicates/similarity
    final existingResponse = await _client
        .from('recent_prompts')
        .select('id, prompt')
        .eq('user_id', user.id);

    final existingItems = List<Map<String, dynamic>>.from(existingResponse);
    final normalizedNew = _normalize(prompt);

    String? idToDelete;

    for (var item in existingItems) {
      final oldPrompt = item['prompt'] as String;
      final normalizedOld = _normalize(oldPrompt);

      if (_areSimilar(normalizedNew, normalizedOld)) {
        idToDelete = item['id'];
        break;
      }
    }

    if (idToDelete != null) {
      // Delete the old one so we can replace it with the new one
      // (fresh timestamp, maybe new spelling preference)
      await _client.from('recent_prompts').delete().eq('id', idToDelete);
    }

    // 2. Insert the prompt
    await _client.from('recent_prompts').upsert(
      {
        'user_id': user.id,
        'prompt': prompt,
        'created_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id, prompt',
    );

    // 3. Cleanup: Keep only top 10 recent prompts
    final allPrompts = await _client
        .from('recent_prompts')
        .select('id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    if (allPrompts.length > 10) {
      final idsToDelete = allPrompts.skip(10).map((e) => e['id']).toList();
      if (idsToDelete.isNotEmpty) {
        await _client
            .from('recent_prompts')
            .delete()
            .filter('id', 'in', idsToDelete);
      }
    }
  }

  String _normalize(String input) {
    return input.trim().toLowerCase();
  }

  bool _areSimilar(String a, String b) {
    if (a == b) return true;
    // Singular/Plural check
    // "pancake" vs "pancakes"
    if (a + 's' == b || b + 's' == a) return true;
    if (a + 'es' == b || b + 'es' == a) return true;
    return false;
  }

  Future<void> clearAll() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('recent_prompts').delete().eq('user_id', user.id);
  }

  Future<void> restore(List<String> prompts) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final records = prompts
        .map((p) => {
              'user_id': user.id,
              'prompt': p,
              'created_at': DateTime.now().toIso8601String(),
            })
        .toList();

    if (records.isNotEmpty) {
      await _client
          .from('recent_prompts')
          .upsert(records, onConflict: 'user_id, prompt');
    }
  }
}
