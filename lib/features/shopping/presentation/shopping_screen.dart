import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/brand_logo.dart';
import 'package:chefmind_ai/core/widgets/chefmind_watermark.dart';
import 'shopping_controller.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/widgets/nano_toast.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _inputController = TextEditingController();

  void _addItem() {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      ref.read(shoppingControllerProvider.notifier).addItem(text);
      _inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(shoppingControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const BrandLogo(fontSize: 24),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              // Optional: History feature?
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Watermark
          const Positioned(
            left: -40,
            top: 100,
            bottom: 100,
            child: ChefMindWatermark(),
          ),
          Column(
            children: [
              // Input Bar (Nano Banana Style)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GlassContainer(
                  borderRadius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add to cart...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.zestyLime),
                        onPressed: _addItem,
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: AppColors.zestyLime,
                  backgroundColor: AppColors.deepCharcoal,
                  onRefresh: () async {
                    ref.invalidate(shoppingControllerProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: listState.when(
                    data: (items) {
                      final active =
                          items.where((i) => i['is_bought'] == false).toList();
                      final bought =
                          items.where((i) => i['is_bought'] == true).toList();

                      if (items.isEmpty) {
                        return const Center(
                            child: Text("Cart is empty",
                                style: TextStyle(color: Colors.white54)));
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (active.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text("To Buy",
                                  style: TextStyle(
                                      color: AppColors.zestyLime,
                                      fontWeight: FontWeight.bold)),
                            ),
                            ...active
                                .map((item) => _buildCartItem(item, false)),
                          ],
                          if (bought.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text("Recently Bought",
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.bold)),
                            ),
                            ...bought.map((item) => _buildCartItem(item, true)),
                          ],
                        ],
                      );
                    },
                    error: (err, st) => Center(
                        child: Text('Error: $err',
                            style: const TextStyle(color: Colors.red))),
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.zestyLime)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, bool isBought) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Slidable(
            key: Key(item['id'].toString()),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (context) {
                    _confirmDelete(item['id']);
                  },
                  backgroundColor: AppColors.errorRed,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline,
                  label: 'Delete',
                ),
              ],
            ),
            child: GlassContainer(
              borderRadius: 0, // Wrapped by ClipRRect via Slidable
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // isBought styling handled by text opacity mostly, or we can use another widget if needed
              child: Row(
                children: [
                  // Custom Checkbox
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(shoppingControllerProvider.notifier)
                          .toggleItem(item['id'], isBought);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                isBought ? Colors.white38 : AppColors.zestyLime,
                            width: 2),
                        color: isBought ? Colors.white12 : null,
                      ),
                      child: isBought
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white38)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text
                  Expanded(
                    child: Text(
                      item['item_name'] ?? 'Unknown',
                      style: TextStyle(
                        color: isBought ? Colors.white38 : Colors.white,
                        decoration:
                            isBought ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Amount
                  if (item['amount'] != null && item['amount'] != '1')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item['amount'],
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ));
  }

  Future<void> _confirmDelete(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title:
            const Text("Remove Item?", style: TextStyle(color: Colors.white)),
        content: const Text(
            "Are you sure you want to remove this from your cart?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Remove",
                  style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(shoppingControllerProvider.notifier).deleteItem(id);
      if (mounted) NanoToast.showInfo(context, "Item removed from cart");
    }
  }
}
