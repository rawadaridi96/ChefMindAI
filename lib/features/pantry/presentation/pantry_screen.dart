import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/brand_logo.dart';
import 'package:chefmind_ai/core/widgets/chefmind_watermark.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'pantry_controller.dart';
import '../../../../core/widgets/nano_toast.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'package:chefmind_ai/features/scanner/presentation/scanner_screen.dart';
import '../../../../core/widgets/network_error_view.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
  bool _isFabExpanded = false;
  late AnimationController _fabController;

  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
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
        onAdd: (name, qty, unit) async {
          final fullText =
              qty != null && qty.isNotEmpty ? "$qty $unit $name" : name;
          final success = await ref
              .read(pantryControllerProvider.notifier)
              .addIngredient(fullText, 'General');

          Navigator.pop(ctx);

          if (success) {
            NanoToast.showSuccess(context, "Added $name to Pantry!");
          } else {
            NanoToast.showInfo(context, "$name is already in your pantry.");
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantryState = ref.watch(pantryControllerProvider);

    ref.listen(pantryControllerProvider, (_, next) {
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.pantrySearchHint,
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              )
            : const BrandLogo(fontSize: 24),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search,
                color: Colors.white),
            onPressed: _toggleSearch,
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
      floatingActionButton: _buildCircularFab(),
      // floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, // Removed to allow default 'endFloat' which adapts to RTL

      body: Stack(
        children: [
          // Watermark
          const Positioned(
            left: -24,
            top: 100,
            bottom: 100,
            child: ChefMindWatermark(),
          ),
          // Content
          Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.zestyLime,
                  backgroundColor: AppColors.deepCharcoal,
                  onRefresh: () async {
                    // Trigger manual sync
                    await ref.read(pantryControllerProvider.notifier).refresh();
                  },
                  child: pantryState.when(
                    data: (items) => _buildList(items),
                    error: (err, st) {
                      if (pantryState.hasValue) {
                        return _buildList(pantryState.value!);
                      }

                      if (NetworkErrorView.isNetworkError(err)) {
                        return NetworkErrorView(
                          onRetry: () {
                            ref.invalidate(pantryControllerProvider);
                          },
                        );
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 48,
                                  color: AppColors.errorRed.withOpacity(0.8)),
                              const SizedBox(height: 16),
                              const Text(
                                'Oops! Something went wrong.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                err.toString(),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  ref.invalidate(pantryControllerProvider);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      );
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
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    // Filter items based on search query
    final filteredItems = items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    if (filteredItems.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Text(
                  'No matching ingredients found.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.kitchen_outlined, size: 64, color: Colors.white12),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.pantryEmpty,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Padding for FAB
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildPremiumCard(item);
      },
    );
  }

  Widget _buildPremiumCard(Map<String, dynamic> item) {
    final createdString = item['created_at'] != null
        ? DateFormat('MMM d').format(DateTime.parse(item['created_at']))
        : 'Today';

    String displayName = _capitalize(item['name'] ?? 'Unknown');
    String? displayQty;

    // Quantity Parsing Logic
    final parts = displayName.split(' ');
    if (parts.isNotEmpty &&
        double.tryParse(parts[0]) != null &&
        parts.length > 1) {
      displayQty = parts[0];
      if (parts.length > 2 &&
          [
            'g',
            'kg',
            'ml',
            'l',
            'oz',
            'lb',
            'pcs',
            'doz',
            'bottle',
            'box',
            'can',
            'jar',
            'bag',
            'pack'
          ].contains(parts[1].toLowerCase().replaceAll('s', ''))) {
        displayQty += " ${parts[1]}";
        displayName = parts.sublist(2).join(' ');
      } else {
        displayName = parts.sublist(1).join(' ');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05), // Fallback
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          image: item['image_url'] != null &&
                  (item['image_url'] as String).isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(item['image_url']),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.6), BlendMode.darken),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon Container (Hide if image exists to reduce clutter, or keep?)
              // Keep for consistency, maybe transparent?
              if (item['image_url'] == null)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.zestyLime.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.kitchen,
                      color: AppColors.zestyLime, size: 24),
                )
              else
                const SizedBox(
                    height: 48), // Spacer to keep height consistency if needed

              if (item['image_url'] == null) const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          "Added $createdString",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4)
                              ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quantity Badge (if exists)
              if (displayQty != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        AppColors.zestyLime.withOpacity(0.2), // Keep same style
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.zestyLime.withOpacity(0.3)),
                  ),
                  child: Text(
                    displayQty,
                    style: const TextStyle(
                      color: AppColors.zestyLime,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Delete Button
              GestureDetector(
                onTap: () => _confirmDelete(item['id'], displayName),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Colors.black45, // Darker bg for visibility over image
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((str) {
      if (str.isEmpty) return str;
      return "${str[0].toUpperCase()}${str.substring(1)}";
    }).join(' ');
  }

  Future<void> _confirmDelete(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title: Text(AppLocalizations.of(context)!.pantryDeleteConfirm(name),
            style: const TextStyle(color: Colors.white)),
        content: Text(AppLocalizations.of(context)!.pantryDeleteMessage,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.generalCancel,
                  style: const TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.generalDelete,
                  style: const TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(pantryControllerProvider.notifier).deleteIngredient(id);
      if (mounted)
        NanoToast.showInfo(
            context, AppLocalizations.of(context)!.pantryIngredientRemoved);
    }
  }

  Widget _buildCircularFab() {
    return Flow(
      delegate: _FlowMenuDelegate(
        controller: _fabController,
        textDirection: Directionality.of(context),
      ),
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
  final ui.TextDirection textDirection;

  _FlowMenuDelegate({required this.controller, required this.textDirection})
      : super(repaint: controller);

  @override
  void paintChildren(FlowPaintingContext context) {
    final n = context.childCount;
    // Determine the anchor X based on direction
    final isRtl = textDirection == ui.TextDirection.rtl;

    for (int i = 0; i < n; i++) {
      final isMain = i == 0;
      final childSize = context.getChildSize(i)!.width;

      if (isMain) {
        // Main button position specific to LTR/RTL
        // The standard LTR logical position for a FAB is Bottom-Right.
        // In screen coordinates, Right is `width - childSize`.
        // The standar RTL logical position for a FAB is Bottom-Left.
        // In screen coordinates, Left is `0`.
        // However, Flow paints in (0,0) based relative coordinates if it's full screen.
        // IF Flow fills the screen (likely in a Scaffold body Stack), then:

        double x;
        double y = context.size.height - childSize;

        if (isRtl) {
          x = 0; // Align to Left
        } else {
          x = context.size.width - childSize; // Align to Right
        }

        context.paintChild(i, transform: Matrix4.identity()..translate(x, y));
      } else {
        final double rad = 80 * controller.value;
        final scale = controller.value;

        // Fan out logic
        double xBase;
        if (isRtl) {
          xBase = 0;
        } else {
          xBase = context.size.width - childSize;
        }

        final double dxOffset = (i == 1 ? 0 : (isRtl ? rad * 0.8 : -rad * 0.8));
        final double dyOffset = (i == 1 ? -rad : -rad * 0.5);

        final double dx = xBase + dxOffset;
        final double dy = (context.size.height - childSize) + dyOffset;

        context.paintChild(i,
            transform: Matrix4.identity()
              ..translate(dx, dy)
              ..scale(scale, scale));
      }
    }
  }

  @override
  bool shouldRepaint(_FlowMenuDelegate oldDelegate) =>
      controller != oldDelegate.controller ||
      textDirection != oldDelegate.textDirection;
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
    'doz',
    'Bottle',
    'Box',
    'Can',
    'Jar',
    'Bag',
    'Pack'
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
              Text(AppLocalizations.of(context)!.pantryAddIngredient,
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
                      AppLocalizations.of(context)!.pantryIngredientNameLabel,
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
                              AppLocalizations.of(context)!.pantryQuantityOpt,
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
                  child: Text(AppLocalizations.of(context)!.pantryAddToPantry,
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
