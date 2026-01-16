import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'pantry_controller.dart';
import '../../../../core/widgets/nano_toast.dart';
import 'package:intl/intl.dart';

import 'package:chefmind_ai/features/scanner/presentation/scanner_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
  bool _isFabExpanded = false;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _openScanner() {
    _toggleFab();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  void _openManualEntry() {
    _toggleFab();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualEntryModal(
        onAdd: (name, qty, unit) {
          final fullText =
              qty != null && qty.isNotEmpty ? "$qty $unit $name" : name;
          ref
              .read(pantryControllerProvider.notifier)
              .addIngredient(fullText, 'General');
          Navigator.pop(ctx);
          NanoToast.showSuccess(context, "Added $name to Pantry!");
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantryState = ref.watch(pantryControllerProvider);

    ref.listen(pantryControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        NanoToast.showError(context, next.error.toString());
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildCircularFab(),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.zestyLime,
              backgroundColor: AppColors.deepCharcoal,
              onRefresh: () async {
                ref.invalidate(pantryControllerProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: pantryState.when(
                data: (items) => _buildList(items),
                error: (err, st) {
                  if (pantryState.hasValue) {
                    return _buildList(pantryState.value!);
                  }
                  return Center(
                      child: Text('Error: $err',
                          style: const TextStyle(color: AppColors.errorRed)));
                },
                loading: () => pantryState.hasValue
                    ? Stack(
                        children: [
                          _buildList(pantryState.value!),
                          const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.zestyLime)),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.zestyLime)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
          child: Text('Your pantry is empty. Tap + to add ingredients!',
              style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final createdString = item['created_at'] != null
            ? DateFormat('MMM d').format(DateTime.parse(item['created_at']))
            : 'Today';

        String displayName = _capitalize(item['name'] ?? 'Unknown');
        String? displayQty;

        final parts = displayName.split(' ');
        if (parts.isNotEmpty &&
            double.tryParse(parts[0]) != null &&
            parts.length > 1) {
          displayQty = parts[0];
          if (parts.length > 2 &&
              ['g', 'kg', 'ml', 'l', 'oz', 'lb', 'pcs', 'doz']
                  .contains(parts[1].toLowerCase())) {
            displayQty += " ${parts[1]}";
            displayName = parts.sublist(2).join(' ');
          } else {
            displayName = parts.sublist(1).join(' ');
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
                borderRadius: 0,
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.zestyLime.withOpacity(0.2),
                    child: const Icon(Icons.kitchen,
                        color: AppColors.zestyLime, size: 16),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      if (displayQty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(displayQty,
                              style: const TextStyle(
                                  color: AppColors.zestyLime,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text("Added: $createdString",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((str) {
      if (str.isEmpty) return str;
      return "${str[0].toUpperCase()}${str.substring(1)}";
    }).join(' ');
  }

  Future<void> _confirmDelete(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title:
            const Text("Delete Item?", style: TextStyle(color: Colors.white)),
        content: const Text("Remove this ingredient from your pantry?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete",
                  style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(pantryControllerProvider.notifier).deleteIngredient(id);
      if (mounted)
        NanoToast.showInfo(context, "Ingredient removed from pantry");
    }
  }

  Widget _buildCircularFab() {
    return Flow(
      delegate: _FlowMenuDelegate(controller: _fabController),
      children: [
        FloatingActionButton(
          heroTag: "fab_main",
          onPressed: _toggleFab,
          backgroundColor: AppColors.zestyLime,
          foregroundColor: AppColors.deepCharcoal,
          child: AnimatedIcon(
            icon: AnimatedIcons.add_event,
            progress: _fabController,
          ),
        ),
        FloatingActionButton.small(
          heroTag: "fab_manual",
          onPressed: _openManualEntry,
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.zestyLime,
          child: const Icon(Icons.edit_outlined),
        ),
        FloatingActionButton.small(
          heroTag: "fab_camera",
          onPressed: _openScanner,
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.zestyLime,
          child: const Icon(Icons.camera_alt_outlined),
        ),
      ],
    );
  }
}

class _FlowMenuDelegate extends FlowDelegate {
  final Animation<double> controller;

  _FlowMenuDelegate({required this.controller}) : super(repaint: controller);

  @override
  void paintChildren(FlowPaintingContext context) {
    final n = context.childCount;
    for (int i = 0; i < n; i++) {
      final isMain = i == 0;
      final childSize = context.getChildSize(i)!.width;

      if (isMain) {
        context.paintChild(i,
            transform: Matrix4.identity()
              ..translate(context.size.width - childSize,
                  context.size.height - childSize));
      } else {
        final double rad = 80 * controller.value;
        final double dx =
            (context.size.width - childSize) + (i == 1 ? 0 : -rad * 0.8);
        final double dy =
            (context.size.height - childSize) + (i == 1 ? -rad : -rad * 0.5);
        final scale = controller.value;

        context.paintChild(i,
            transform: Matrix4.identity()
              ..translate(dx, dy)
              ..scale(scale, scale));
      }
    }
  }

  @override
  bool shouldRepaint(_FlowMenuDelegate oldDelegate) =>
      controller != oldDelegate.controller;
}

class _ManualEntryModal extends StatefulWidget {
  final Function(String name, String? qty, String unit) onAdd;

  const _ManualEntryModal({required this.onAdd});

  @override
  State<_ManualEntryModal> createState() => _ManualEntryModalState();
}

class _ManualEntryModalState extends State<_ManualEntryModal> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _selectedUnit = 'pcs';

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
    'doz'
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
              const Text("Add Ingredient",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Ingredient Name",
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
              Row(
                children: [
                  Expanded(
                    flex: 1,
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
                  child: const Text("Add to Pantry",
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
