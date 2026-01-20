import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/brand_logo.dart';
import 'package:chefmind_ai/core/widgets/chefmind_watermark.dart';
import 'shopping_controller.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/widgets/nano_toast.dart';

import '../../settings/presentation/household_controller.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  void _openManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualEntryModal(
        onAdd: (name, qty, unit) async {
          final fullAmount = qty != null && qty.isNotEmpty ? "$qty $unit" : "1";

          await ref.read(shoppingControllerProvider.notifier).addItem(
                name,
                amount: fullAmount,
              );

          Navigator.pop(ctx);
          if (mounted) NanoToast.showInfo(context, "Added $name to Cart");
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(shoppingControllerProvider);
    final isSyncEnabled = ref.watch(shoppingSyncEnabledProvider);
    // Ensure household state is loaded/kept alive while on this screen
    ref.watch(householdControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const BrandLogo(fontSize: 24),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(isSyncEnabled ? Icons.diversity_3 : Icons.person,
              color: isSyncEnabled ? AppColors.zestyLime : Colors.white54),
          tooltip: "Family Sync", // "Toggle Family Sync" behavior
          onPressed: () {
            // Check if user is in a household
            final householdState = ref.read(householdControllerProvider);
            // householdState is AsyncValue<Map<String, dynamic>?>
            // We can check if value is present and not null
            final household = householdState.valueOrNull;

            if (household == null) {
              NanoToast.showInfo(
                  context, "Join a household in Settings to sync.");
              return;
            }

            ref.read(shoppingSyncEnabledProvider.notifier).toggle();
            if (!isSyncEnabled) {
              NanoToast.showInfo(context, "Family Sync Active");
            } else {
              NanoToast.showInfo(context, "Personal Cart Active");
            }
          },
        ),
        actions: [
          // Presence Bubbles (Visible only when Sync is ON)
          if (isSyncEnabled)
            Consumer(
              builder: (context, ref, child) {
                final membersState = ref.watch(householdMembersProvider);
                return membersState.when(
                  data: (members) {
                    if (members.isEmpty) return const SizedBox.shrink();

                    // Take max 3 or 4 to avoid overflow
                    final displayMembers = members.take(4).toList();
                    final double overlap = 12.0;

                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: SizedBox(
                        height: 32,
                        width: (32.0 * displayMembers.length) -
                            (overlap * (displayMembers.length - 1)),
                        child: Stack(
                          children:
                              List.generate(displayMembers.length, (index) {
                            final member = displayMembers[index];
                            final name = member['display_name'] ??
                                member['email'] ??
                                'User';
                            final initial =
                                name.isNotEmpty ? name[0].toUpperCase() : '?';
                            final photoUrl = member['avatar_url'] as String?;

                            return Positioned(
                              left: index * (32.0 - overlap),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors
                                        .deepCharcoal, // Gap color matching bg
                                    width: 2,
                                  ),
                                  color: AppColors.surfaceDark,
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      AppColors.zestyLime.withOpacity(0.2),
                                  backgroundImage:
                                      photoUrl != null && photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                  child: photoUrl == null || photoUrl.isEmpty
                                      ? Text(initial,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.zestyLime,
                                              fontWeight: FontWeight.bold))
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                  error: (_, __) => const SizedBox.shrink(),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              },
            ),

          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () {
              // Confirm Dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.deepCharcoal,
                  title: const Text("Clear Shopping List?",
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      "This will remove all items from your cart. This action cannot be undone.",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        ref
                            .read(shoppingControllerProvider.notifier)
                            .clearAll();
                      },
                      child: const Text("Clear All",
                          style: TextStyle(color: AppColors.errorRed)),
                    ),
                  ],
                ),
              );
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openManualEntry,
        backgroundColor: AppColors.zestyLime,
        child: const Icon(Icons.add, color: AppColors.deepCharcoal),
      ),
      body: Stack(
        children: [
          // Watermark
          const Positioned(
            left: -24,
            top: 100,
            bottom: 100,
            child: ChefMindWatermark(),
          ),

          // Main Content with Glow Effect if Sync is ON
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(4), // Small margin for border
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isSyncEnabled
                  ? Border.all(
                      color: AppColors.zestyLime.withOpacity(0.5), width: 1.5)
                  : Border.all(color: Colors.transparent),
              boxShadow: isSyncEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.zestyLime.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                // Input Bar (Nano Banana Style)

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
                        final active = items
                            .where((i) => i['is_bought'] == false)
                            .toList();
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
                              ...bought
                                  .map((item) => _buildCartItem(item, true)),
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
                    _confirmDelete(item['id'], item['item_name'] ?? 'Item');
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
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
                              color: isBought
                                  ? Colors.white38
                                  : AppColors.zestyLime,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['item_name'] ?? 'Unknown',
                            style: TextStyle(
                              color: isBought ? Colors.white38 : Colors.white,
                              decoration:
                                  isBought ? TextDecoration.lineThrough : null,
                              decorationColor: Colors.white38,
                              fontSize: 16,
                            ),
                          ),
                          if (item['recipe_source'] != null)
                            Builder(builder: (context) {
                              final rawSource =
                                  item['recipe_source']!.toString();
                              final sources = rawSource
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              if (sources.isEmpty)
                                return const SizedBox.shrink();

                              if (sources.length == 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    "Needed for: ${sources.first}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 10),
                                  ),
                                );
                              }

                              // Multiple sources
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: AppColors.deepCharcoal,
                                      title: const Text("Recipe Sources",
                                          style:
                                              TextStyle(color: Colors.white)),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: sources
                                            .map((s) => Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  child: Text("• $s",
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white70)),
                                                ))
                                            .toList(),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text("Close",
                                                style: TextStyle(
                                                    color:
                                                        AppColors.zestyLime)))
                                      ],
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "Needed for: ${sources.first} ",
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10),
                                        ),
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "+${sources.length - 1}",
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    // Quantity Stepper
                    // Trailing Action
                    if (!isBought) ...[
                      if (item['amount'] != null &&
                          item['amount'].toString().trim().isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStepperBtn(
                                  Icons.remove,
                                  Colors.white54,
                                  () => _updateQuantity(
                                      item['id'], item['amount'] ?? '1', -1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 60),
                                  child: Text(
                                    item['amount'] ?? '1',
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              _buildStepperBtn(
                                  Icons.add,
                                  AppColors.zestyLime,
                                  () => _updateQuantity(
                                      item['id'], item['amount'] ?? '1', 1)),
                            ],
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () {
                            // Initialize to 1
                            // We call updateQuantity with current='', change=1 -> result '1'
                            _updateQuantity(item['id'], '', 1);
                          },
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.zestyLime),
                          tooltip: "Add Quantity",
                        )
                    ] else if (item['amount'] != null &&
                        item['amount'].toString().isNotEmpty &&
                        item['amount'] != '1')
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStepperBtn(
                                Icons.remove,
                                Colors.white54,
                                () => _updateQuantity(
                                    item['id'], item['amount'] ?? '1', -1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 60),
                                child: Text(
                                  item['amount'] ?? '1',
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            _buildStepperBtn(
                                Icons.add,
                                AppColors.zestyLime,
                                () => _updateQuantity(
                                    item['id'], item['amount'] ?? '1', 1)),
                          ],
                        ),
                      )
                    else if (item['amount'] != null && item['amount'] != '1')
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
          ),
        ));
  }

  Future<void> _updateQuantity(int id, String currentAmount, int change) async {
    await ref
        .read(shoppingControllerProvider.notifier)
        .updateQuantity(id, currentAmount, change);
  }

  Widget _buildStepperBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Future<void> _confirmDelete(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title:
            Text("Remove $name?", style: const TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to remove $name from your cart?",
            style: const TextStyle(color: Colors.white70)),
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

class _ManualEntryModal extends StatefulWidget {
  final Function(String name, String? qty, String unit) onAdd;
  final String? initialName;

  const _ManualEntryModal({required this.onAdd, this.initialName});

  @override
  State<_ManualEntryModal> createState() => _ManualEntryModalState();
}

class _ManualEntryModalState extends State<_ManualEntryModal> {
  late TextEditingController _nameCtrl;
  final _qtyCtrl = TextEditingController();
  String _selectedUnit = 'pcs';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  final List<String> _units = [
    'g',
    'kg',
    'oz',
    'lb',
    'ml',
    'L',
    'tsp',
    'tbsp',
    'cup',
    'pcs',
    'doz',
    'Bottle',
    'Box',
    'Bag',
    'Can',
    'Jar',
    'Packet'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name, _qtyCtrl.text.trim(), _selectedUnit);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Add to Cart",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Item Name",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Quantity (Opt.)",
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedUnit,
                            dropdownColor: AppColors.surfaceDark,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppColors.zestyLime),
                            items: _units
                                .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedUnit = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.zestyLime,
                    foregroundColor: AppColors.deepCharcoal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Add to Cart",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
