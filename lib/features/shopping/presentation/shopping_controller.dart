import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/shopping_repository.dart';
import '../data/retail_unit_helper.dart';
import '../../../../core/services/offline_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../settings/presentation/household_controller.dart';

part 'shopping_controller.g.dart';

@riverpod
class ShoppingSyncEnabled extends _$ShoppingSyncEnabled {
  @override
  bool build() => false; // Default to private

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

@riverpod
class ShoppingController extends _$ShoppingController {
  @override
  Stream<List<Map<String, dynamic>>> build() {
    // Check Toggle State
    final isSyncEnabled = ref.watch(shoppingSyncEnabledProvider);

    String? householdId;
    // We can't use await in Stream build easily for initial value if we want to be synchronous-like
    // But we CAN read current value if we want, or just watch.
    // However, householdControllerProvider returns AsyncValue.
    // We should watch it.
    final householdAsync = ref.watch(householdControllerProvider);

    if (isSyncEnabled && householdAsync.hasValue) {
      householdId = householdAsync.value?['id'] as String?;
    }

    // Trigger background sync (repository is keepAlive, so this is safe)
    final repo = ref.read(shoppingRepositoryProvider);
    repo.syncCartItems().ignore();

    // Subscribe to Hive Stream
    return repo.watchCartItems(householdId: householdId);
  }

  Future<void> addItem(String name,
      {String amount = '1',
      String category = 'General',
      String? recipeSource,
      String? householdIdOverride,
      bool forcePrivate = false}) async {
    final repo = ref.read(shoppingRepositoryProvider);
    final isSyncEnabled = ref.read(shoppingSyncEnabledProvider);

    String? householdId;

    if (forcePrivate) {
      householdId = null;
    } else if (householdIdOverride != null) {
      householdId = householdIdOverride;
    } else if (isSyncEnabled) {
      final household = ref.read(householdControllerProvider).valueOrNull;
      householdId = household?['id'] as String?;
      debugPrint("DEBUG addItem: Provider householdId = $householdId");

      // Fallback: If provider is not ready (e.g. offline init), check cache directly
      if (householdId == null) {
        try {
          final box = Hive.box('app_prefs');
          final cached = box.get('household_data');
          if (cached != null) {
            householdId = cached['id'];
            debugPrint(
                "DEBUG addItem: Cache fallback householdId = $householdId");
          }
        } catch (e) {
          debugPrint("DEBUG addItem: Cache fallback error = $e");
        }
      }
    }
    debugPrint(
        "DEBUG addItem: Final householdId = $householdId, isSyncEnabled = $isSyncEnabled, forcePrivate=$forcePrivate, override=$householdIdOverride");

    // We can't easily check for duplicates synchronously against "state" if state is Stream
    // But we can check state.value if available
    final currentItems = state.value ?? [];

    final normalizedName = name.toLowerCase().trim();

    final existingItem = currentItems.firstWhere(
      (item) =>
          (item['item_name'] as String).toLowerCase().trim() ==
              normalizedName &&
          (item['is_bought'] == false) &&
          item['household_id'] == householdId,
      orElse: () => {},
    );

    if (existingItem.isNotEmpty) {
      String currentAmountStr = existingItem['amount'] ?? '1';
      double currentVal = _parseAmount(currentAmountStr);
      double incomingVal = _parseAmount(amount);

      if (currentVal > 0 && incomingVal > 0) {
        double total = currentVal + incomingVal;
        String newAmount =
            total % 1 == 0 ? total.toInt().toString() : total.toString();
        String finalAmount = RetailUnitHelper.toRetailUnit(name, newAmount);

        String? currentSource = existingItem['recipe_source'];
        String? finalSource = currentSource;

        if (recipeSource != null) {
          if (currentSource == null || currentSource.isEmpty) {
            finalSource = recipeSource;
          } else {
            List<String> sources =
                currentSource.split(',').map((s) => s.trim()).toList();
            if (!sources.contains(recipeSource)) {
              sources.add(recipeSource);
              finalSource = sources.join(', ');
            }
          }
        }

        await _performOfflineSafe(() => repo.updateAmountAndSource(
            existingItem['id'], finalAmount,
            newSource: finalSource));
      } else {
        await _performOfflineSafe(() => repo.addItem(
            name, RetailUnitHelper.toRetailUnit(name, amount), category,
            recipeSource: recipeSource, householdId: householdId));
      }
    } else {
      String finalAmount = RetailUnitHelper.toRetailUnit(name, amount);
      await _performOfflineSafe(() => repo.addItem(name, finalAmount, category,
          recipeSource: recipeSource, householdId: householdId));
    }
  }

  Future<void> updateQuantity(
      dynamic id, String currentAmount, int change) async {
    double val = 0;
    if (currentAmount.trim().isEmpty) {
      val = 0;
    } else {
      val = _parseAmount(currentAmount);
      if (val <= 0) val = 1;
    }

    double newVal = val + change;
    String newAmountStr;
    if (newVal <= 0) {
      newAmountStr = '';
    } else {
      newAmountStr =
          newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toString();
      if (currentAmount.trim().isNotEmpty) {
        List<String> parts = currentAmount.split(' ');
        if (parts.length > 1) {
          String suffix = parts.sublist(1).join(' ');
          newAmountStr = "$newAmountStr $suffix";
        }
      }
    }

    await _performOfflineSafe(() =>
        ref.read(shoppingRepositoryProvider).updateAmount(id, newAmountStr));
  }

  double _parseAmount(String amount) {
    try {
      final clean = amount.toLowerCase().trim();
      if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 2) {
          return double.parse(parts[0]) / double.parse(parts[1]);
        }
      }
      final match = RegExp(r'^(\d+(\.\d+)?)').firstMatch(clean);
      if (match != null) {
        return double.parse(match.group(1)!);
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  Future<void> toggleItem(dynamic id, bool currentValue) async {
    await _performOfflineSafe(() =>
        ref.read(shoppingRepositoryProvider).toggleStatus(id, !currentValue));
  }

  Future<void> deleteItem(dynamic id) async {
    await _performOfflineSafe(
        () => ref.read(shoppingRepositoryProvider).deleteItem(id));
  }

  Future<void> clearAll() async {
    final isSyncEnabled = ref.read(shoppingSyncEnabledProvider);
    String? householdId;
    if (isSyncEnabled) {
      final household = ref.read(householdControllerProvider).valueOrNull;
      householdId = household?['id'] as String?;

      if (householdId == null) {
        try {
          final box = Hive.box('app_prefs');
          final cached = box.get('household_data');
          if (cached != null) householdId = cached['id'];
        } catch (_) {}
      }
    }
    await _performOfflineSafe(() => ref
        .read(shoppingRepositoryProvider)
        .clearAllItems(householdId: householdId));
  }

  // Helper to clear bought items separately since it logic might differ
  Future<void> clearBought() async {
    final isSyncEnabled = ref.read(shoppingSyncEnabledProvider);
    String? householdId;
    if (isSyncEnabled) {
      final household = ref.read(householdControllerProvider).valueOrNull;
      householdId = household?['id'] as String?;

      if (householdId == null) {
        try {
          final box = Hive.box('app_prefs');
          final cached = box.get('household_data');
          if (cached != null) householdId = cached['id'];
        } catch (_) {}
      }
    }
    await _performOfflineSafe(() => ref
        .read(shoppingRepositoryProvider)
        .clearBoughtItems(householdId: householdId));
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
