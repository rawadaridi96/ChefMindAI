import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/emoji_helper.dart';

class IngredientPickerDialog extends ConsumerStatefulWidget {
  final Function(List<String> selected) onFinish;

  const IngredientPickerDialog({super.key, required this.onFinish});

  @override
  ConsumerState<IngredientPickerDialog> createState() =>
      _IngredientPickerDialogState();
}

class _IngredientPickerDialogState
    extends ConsumerState<IngredientPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = {};

  // Hardcoded for now, ideally fetched from a repository or constants
  final List<String> _popularIngredients = [
    'Chicken',
    'Rice',
    'Onion',
    'Garlic',
    'Tomato',
    'Egg',
    'Milk',
    'Cheese',
    'Potato',
    'Carrot',
    'Beef',
    'Pasta',
    'Bread',
    'Butter',
    'Oil',
    'Salt',
    'Pepper',
    'Lemon',
    'Spinach',
    'Mushroom'
  ];

  List<String> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    // Ideally search a larger database. For now, filter popular + echo query
    // If we had a huge list, we'd search it.
    // Here we just allow adding whatever the user types if it's not in the list.
    setState(() {
      _searchResults = _popularIngredients
          .where((i) => i.toLowerCase().contains(query))
          .toList();

      // If exact match not found, allow adding custom
      if (!_searchResults.any((s) => s.toLowerCase() == query)) {
        // We don't add it to the list immediately, but we could show a "Add 'query'" button
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleItem(String item) {
    setState(() {
      if (_selected.contains(item)) {
        _selected.remove(item);
      } else {
        _selected.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchCtrl.text.isNotEmpty;
    final displayList = isSearching ? _searchResults : _popularIngredients;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Add Ingredients",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        widget.onFinish(_selected.toList());
                        Navigator.pop(context);
                      },
                      child: const Text("Done",
                          style: TextStyle(
                              color: AppColors.zestyLime, fontSize: 16)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search ingredients (e.g. Chicken)...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Selected Chips
          if (_selected.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _selected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _selected.elementAt(index);
                  return Chip(
                    label: Text(item,
                        style: const TextStyle(color: AppColors.deepCharcoal)),
                    backgroundColor: AppColors.zestyLime,
                    deleteIcon: const Icon(Icons.close,
                        size: 16, color: AppColors.deepCharcoal),
                    onDeleted: () => _toggleItem(item),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: displayList.length + (isSearching ? 1 : 0),
              itemBuilder: (context, index) {
                if (isSearching && index == displayList.length) {
                  // "Add Custom" button
                  final query = _searchCtrl.text.trim();
                  if (query.isEmpty ||
                      displayList
                          .any((s) => s.toLowerCase() == query.toLowerCase()))
                    return const SizedBox();

                  return GestureDetector(
                    onTap: () {
                      final formatted =
                          query[0].toUpperCase() + query.substring(1);
                      _toggleItem(formatted);
                      _searchCtrl.clear();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.zestyLime.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.zestyLime, width: 1),
                          ),
                          child:
                              const Icon(Icons.add, color: AppColors.zestyLime),
                        ),
                        const SizedBox(height: 8),
                        Text("Add \"$query\"",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.zestyLime, fontSize: 12),
                            textAlign: TextAlign.center)
                      ],
                    ),
                  );
                }

                final item = displayList[index];
                final isSelected = _selected.contains(item);
                final emoji = EmojiHelper.getEmoji(item) ?? '🥣';

                return GestureDetector(
                  onTap: () => _toggleItem(item),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.zestyLime
                              : Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.zestyLime, width: 2)
                              : Border.all(color: Colors.white10),
                        ),
                        alignment: Alignment.center,
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 8),
                      Text(item,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.zestyLime
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
