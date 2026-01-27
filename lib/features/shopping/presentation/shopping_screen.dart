import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/brand_logo.dart';
import 'package:chefmind_ai/core/widgets/chefmind_watermark.dart';
import 'shopping_controller.dart';
import '../../../../core/widgets/nano_toast.dart';
import '../../../../core/widgets/network_error_view.dart';
import '../../../../core/utils/emoji_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
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

    ref.listen(shoppingControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        if (NetworkErrorView.isNetworkError(next.error!)) {
          NanoToast.showError(
              context, "No connection. Please check your internet.");
        } else {
          NanoToast.showError(context, next.error.toString());
        }
      }
    });

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
            // 1. Check Household
            final householdState = ref.read(householdControllerProvider);
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
            icon: Icon(Icons.delete_outline,
                color: (listState.hasValue &&
                        listState.value!.isNotEmpty &&
                        !NetworkErrorView.isNetworkError(
                            listState.error ?? Object()))
                    ? Colors.white70
                    : Colors.white12),
            onPressed: (listState.hasValue &&
                    listState.value!.isNotEmpty &&
                    !NetworkErrorView.isNetworkError(
                        listState.error ?? Object()))
                ? () {
                    // Confirm Dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.deepCharcoal,
                        title: Text(
                            AppLocalizations.of(context)!
                                .shoppingClearDialogTitle,
                            style: const TextStyle(color: Colors.white)),
                        content: Text(
                            AppLocalizations.of(context)!
                                .shoppingClearDialogContent,
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                                AppLocalizations.of(context)!
                                    .shoppingClearDialogCancel,
                                style: const TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              ref
                                  .read(shoppingControllerProvider.notifier)
                                  .clearAll();
                            },
                            child: Text(
                                AppLocalizations.of(context)!
                                    .shoppingClearDialogConfirm,
                                style:
                                    const TextStyle(color: AppColors.errorRed)),
                          ),
                        ],
                      ),
                    );
                  }
                : null,
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
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                    AppLocalizations.of(context)!.shoppingToBuy,
                                    style: const TextStyle(
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
                      error: (err, st) {
                        if (NetworkErrorView.isNetworkError(err)) {
                          return NetworkErrorView(
                            onRetry: () {
                              ref.invalidate(shoppingControllerProvider);
                            },
                          );
                        }
                        return Center(
                            child: Text('Error: $err',
                                style: const TextStyle(color: Colors.red)));
                      },
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(item['id'].toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.errorRed.withOpacity(0.8),
                AppColors.errorRed,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.errorRed.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.delete_forever_rounded,
                  color: Colors.white, size: 28),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          // Use existing confirm dialog logic, adapted to return bool
          return await _confirmDelete(item['id'], item['item_name'] ?? 'Item');
        },
        child: Container(
          decoration: BoxDecoration(
            color: isBought
                ? Colors.white.withOpacity(0.02)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isBought
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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

                // Thumbnail (New)
                // Thumbnail (New Sticker Style)
                // Emoji Icon (Glass Bubble Style)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08), // Glassy background
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    EmojiHelper.getEmoji(item['item_name'] ?? ''),
                    style: const TextStyle(fontSize: 24),
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
                          decorationColor: AppColors.zestyLime,
                          decorationThickness: 2,
                          fontSize: 16,
                          fontWeight:
                              isBought ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                      if (item['recipe_source'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: _buildRecipeSources(
                              item['recipe_source'].toString()),
                        ),
                    ],
                  ),
                ),

                // Quantity / Add Buttons
                if (!isBought) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStepperBtn(
                            Icons.remove,
                            Colors.white54,
                            () => _updateQuantity(
                                item['id'], item['amount'] ?? '1', -1)),
                        Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          alignment: Alignment.center,
                          child: Text(
                            item['amount'] ?? '1',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
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
                ] else if (item['amount'] != null && item['amount'] != '1')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item['amount'],
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeSources(String rawSource) {
    final sources = rawSource
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (sources.isEmpty) return const SizedBox.shrink();

    if (sources.length == 1) {
      return Row(
        children: [
          Icon(Icons.restaurant_menu,
              size: 10, color: AppColors.zestyLime.withOpacity(0.7)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              "For: ${sources.first}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.zestyLime.withOpacity(0.7), fontSize: 11),
            ),
          ),
        ],
      );
    }

    // Multiple sources
    return GestureDetector(
      onTap: () {
        // Show dialog (keep existing logic or simplified)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.deepCharcoal,
            title: const Text("Recipe Sources",
                style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sources
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text("• $s",
                            style: const TextStyle(color: Colors.white70)),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close",
                      style: TextStyle(color: AppColors.zestyLime)))
            ],
          ),
        );
      },
      child: Row(
        children: [
          Icon(Icons.restaurant_menu,
              size: 10, color: AppColors.zestyLime.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(
            "For: ${sources.first}",
            style: TextStyle(
                color: AppColors.zestyLime.withOpacity(0.7), fontSize: 11),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            decoration: BoxDecoration(
              color: AppColors.zestyLime.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "+${sources.length - 1}",
              style: const TextStyle(
                  color: AppColors.zestyLime,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(
      dynamic id, String currentAmount, int change) async {
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

  Future<bool> _confirmDelete(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title: Text(AppLocalizations.of(context)!.shoppingRemoveConfirm(name),
            style: const TextStyle(color: Colors.white)),
        content: Text(AppLocalizations.of(context)!.shoppingRemoveMessage(name),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.generalCancel,
                  style: const TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.generalRemove,
                  style: const TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(shoppingControllerProvider.notifier).deleteItem(id);
      if (mounted) {
        NanoToast.showInfo(
            context, AppLocalizations.of(context)!.shoppingItemRemoved);
      }
      return true;
    }
    return false;
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
              Text(AppLocalizations.of(context)!.shoppingAddToCart,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.shoppingItemNameLabel,
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
                          labelText:
                              AppLocalizations.of(context)!.shoppingQuantityOpt,
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
                  child: Text(AppLocalizations.of(context)!.shoppingAddToCart,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
