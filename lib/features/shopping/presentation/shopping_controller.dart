import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/shopping_repository.dart';
import '../data/retail_unit_helper.dart';

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
  FutureOr<List<Map<String, dynamic>>> build() async {
    // Check Toggle State
    final isSyncEnabled = ref.watch(shoppingSyncEnabledProvider);

    String? householdId;
    if (isSyncEnabled) {
      // Get Household Context only if sync is enabled
      final household = await ref.watch(householdControllerProvider.future);
      householdId = household?['id'] as String?;
    }

    // Subscribe to realtime stream
    // If householdId is null (either disabled or not in one), repo uses user_id
    final stream = ref
        .read(shoppingRepositoryProvider)
        .getCartStream(householdId: householdId);

    final sub = stream.listen((data) {
      state = AsyncValue.data(data);
    });

    // Ensure subscription is cancelled when provider is destroyed
    ref.onDispose(() => sub.cancel());

    return stream.first;
  }

  Future<void> addItem(String name,
      {String amount = '1',
      String category = 'General',
      String? recipeSource}) async {
    // We don't set state manually anymore, the stream will update.
    // However, we still want to guard the async operation to handle errors.
    final repo = ref.read(shoppingRepositoryProvider);

    // Check Toggle State for ADD operation
    final isSyncEnabled = ref.read(shoppingSyncEnabledProvider);

    // Get Household ID for ensuring we add to the right list/sync
    String? householdId;
    if (isSyncEnabled) {
      final household = await ref.read(householdControllerProvider.future);
      householdId = household?['id'] as String?;
    }

    // FETCH current items just for the logic of consolidation (snapshot interaction)
    // Note: This relies on a single-point-in-time fetch.
    // In a high-frequency realtime env, this might have race conditions, but acceptable for this scale.
    // We must pass householdId to getItems if we want to check duplicates correctly?
    // repo.getItems() currently only fetches by USER_ID.
    // FIXME: repo.getItems() ALSO needs to support householdId if we are in household mode!
    // However, if we are in household mode, the stream has the data.
    // We can check 'state.value' instead of repo.getItems()!
    // Using 'state.value' is much better for consistency with the stream.

    final currentItems = state.value ?? [];
    // Fallback to repo if state is null? async fetch?
    // If state is null, we might be loading.
    // Let's assume state has data if we are calling addItem, or we fetch from repo (but repo needs update).
    // Let's rely on repo.getItems() for now but we need to update repo.getItems() too?
    // Actually, let's just use the current List if available.

    final normalizedName = name.toLowerCase().trim();

    final existingItem = currentItems.firstWhere(
      (item) =>
          (item['item_name'] as String).toLowerCase().trim() ==
              normalizedName &&
          (item['is_bought'] == false),
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

        await repo.updateAmountAndSource(existingItem['id'], finalAmount,
            newSource: finalSource);
      } else {
        await repo.addItem(
            name, RetailUnitHelper.toRetailUnit(name, amount), category,
            recipeSource: recipeSource, householdId: householdId);
      }
    } else {
      String finalAmount = RetailUnitHelper.toRetailUnit(name, amount);
      await repo.addItem(name, finalAmount, category,
          recipeSource: recipeSource, householdId: householdId);
    }
  }

  Future<void> updateQuantity(int id, String currentAmount, int change) async {
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

    await ref.read(shoppingRepositoryProvider).updateAmount(id, newAmountStr);
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

  Future<void> toggleItem(int id, bool currentValue) async {
    await ref.read(shoppingRepositoryProvider).toggleStatus(id, !currentValue);
  }

  Future<void> deleteItem(int id) async {
    await ref.read(shoppingRepositoryProvider).deleteItem(id);
  }

  Future<void> clearAll() async {
    await ref.read(shoppingRepositoryProvider).clearAllItems();
  }
}
