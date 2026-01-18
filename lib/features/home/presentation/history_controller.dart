import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_repository.dart';

// Provider
final historyControllerProvider =
    StateNotifierProvider<HistoryController, AsyncValue<List<String>>>((ref) {
  final repo = ref.watch(historyRepositoryProvider);
  return HistoryController(repo);
});

class HistoryController extends StateNotifier<AsyncValue<List<String>>> {
  final HistoryRepository _repository;

  HistoryController(this._repository) : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.fetchRecentPrompts());
  }

  Future<void> addPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;
    final cleanPrompt = prompt.trim();

    // Optimistic Update
    final currentList = state.value ?? [];
    // Remove if exists to move to top
    final updatedList = [
      cleanPrompt,
      ...currentList.where((p) => p != cleanPrompt)
    ];
    // Limit to 5 for display (Repo limits fetch to 5, we should too)
    if (updatedList.length > 5) {
      updatedList.length = 5;
    }

    state = AsyncValue.data(updatedList);

    // Call API
    try {
      await _repository.addPrompt(cleanPrompt);
      // Optional: Reload to ensure sync, or trust optimistic
      // await loadHistory();
    } catch (e, st) {
      // Revert or show error?
      // Silently fail is usually okay for history, or invalidate
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clearAll() async {
    // Optimistic
    state = const AsyncValue.data([]);

    try {
      await _repository.clearAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restore(List<String> backup) async {
    state = AsyncValue.data(backup);
    try {
      await _repository.restore(backup);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
