import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/shopping_repository.dart';
import '../data/retail_unit_helper.dart';

part 'shopping_controller.g.dart';

@riverpod
class ShoppingController extends _$ShoppingController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return ref.read(shoppingRepositoryProvider).getItems();
  }

  Future<void> addItem(String name,
      {String amount = '1',
      String category = 'General',
      String? recipeSource}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(shoppingRepositoryProvider);
      final currentItems = await repo.getItems();
      final normalizedName = name.toLowerCase().trim();

      // Check for existing item to consolidate
      final existingItem = currentItems.firstWhere(
        (item) =>
            (item['item_name'] as String).toLowerCase().trim() ==
                normalizedName &&
            (item['is_bought'] == false),
        orElse: () => {},
      );

      // Apply Retail Mapping
      // If we are consolidating, we might need a smarter merge, but for now:
      // If it exists, we try to merge amounts.
      // If not, we map the incoming amount.

      if (existingItem.isNotEmpty) {
        // Consolidation Logic
        // Very basic: if amount is just a number, add them.
        // If it's a string like "1 Bottle", we probably step up the count.
        // For this task, "1/2 onion + 1/2 onion = 1 Onion" is requested.

        String currentAmountStr = existingItem['amount'] ?? '1';
        // Try parsing fractions
        double currentVal = _parseAmount(currentAmountStr);
        double incomingVal = _parseAmount(amount);

        if (currentVal > 0 && incomingVal > 0) {
          double total = currentVal + incomingVal;
          // Format back to string, removing .0 if integer
          String newAmount =
              total % 1 == 0 ? total.toInt().toString() : total.toString();

          // After consolidation, check retail unit again?
          // Usually retail unit depends on the name, e.g. "Onion".
          // If total is 1, and name is Onion, result is "1".
          // If name is Salt, result might be "1 Box".

          // Apply retail mapping to the consolidated amount
          String finalAmount = RetailUnitHelper.toRetailUnit(name, newAmount);

          // Merge Recipe Sources
          String? currentSource = existingItem['recipe_source'];
          String? finalSource = currentSource;

          if (recipeSource != null) {
            if (currentSource == null || currentSource.isEmpty) {
              finalSource = recipeSource;
            } else {
              // Avoid duplicates (e.g. "Pancakes, Pancakes")
              // Split, trim, check, join.
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
          // Fallback: just append text if we can't parse? or just add as new?
          // Requirement: "If user adds two recipes... merge".
          // If we can't parse, we might just leave it or overwrite?
          // Let's safe-fail by adding as new if we can't merge, OR just overwrite.
          // For now, let's just add it as a separate item if we can't merge math.
          // But wait, user wants merge. Let's assume simple numbers or fractions.
          // If complex, we skip merge to be safe.
          await repo.addItem(
              name, RetailUnitHelper.toRetailUnit(name, amount), category,
              recipeSource: recipeSource);
        }
      } else {
        // New Item
        String finalAmount = RetailUnitHelper.toRetailUnit(name, amount);
        await repo.addItem(name, finalAmount, category,
            recipeSource: recipeSource);
      }

      return repo.getItems();
    });
  }

  Future<void> updateQuantity(int id, String currentAmount, int change) async {
    // Logic to increment/decrement "1 Bottle", "2 Onions", etc.
    // We assume the amount string starts with a number.
    double val = 0;
    if (currentAmount.trim().isEmpty) {
      val = 0;
    } else {
      val = _parseAmount(currentAmount);
      if (val <= 0) val = 1; // Default start if parse fails but text exists
    }

    double newVal = val + change;

    String newAmountStr;
    if (newVal <= 0) {
      newAmountStr = '';
    } else {
      newAmountStr =
          newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toString();

      // Preserve unit if it exists (e.g. "2 Bottles" -> "3 Bottles")
      // Simple heuristic: split by space.
      if (currentAmount.trim().isNotEmpty) {
        List<String> parts = currentAmount.split(' ');
        if (parts.length > 1) {
          // Re-attach the suffix
          String suffix = parts.sublist(1).join(' ');
          newAmountStr = "$newAmountStr $suffix";
        }
      }
    }

    state = await AsyncValue.guard(() async {
      await ref.read(shoppingRepositoryProvider).updateAmount(id, newAmountStr);
      return ref.read(shoppingRepositoryProvider).getItems();
    });
  }

  double _parseAmount(String amount) {
    try {
      final clean = amount.toLowerCase().trim();
      // Handle fractions
      if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 2) {
          return double.parse(parts[0]) / double.parse(parts[1]);
        }
      }
      // Handle "1 Bottle" -> take "1"
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

  Future<void> clearAll() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(shoppingRepositoryProvider).clearAllItems();
      return []; // Return empty list directly
    });
  }
}
