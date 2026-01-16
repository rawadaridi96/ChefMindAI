import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';

import '../scanner/presentation/scanner_screen.dart';
import '../pantry/presentation/pantry_screen.dart';
import '../recipes/presentation/recipes_screen.dart';
import '../recipes/presentation/recipe_controller.dart';
import '../subscription/presentation/subscription_screen.dart';
import '../shopping/presentation/shopping_screen.dart';
import '../../core/widgets/glass_container.dart';

import 'widgets/pulse_microphone_button.dart';

import '../import/presentation/import_controller.dart';
import '../recipes/presentation/widgets/pantry_generator_widget.dart';
import '../settings/presentation/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Global Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.deepCharcoal, Color(0xFF202020)],
              ),
            ),
          ),
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeDashboard(ref),
                const PantryScreen(),
                const RecipesScreen(),
                const ShoppingScreen(), // Shopping Tab
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.deepCharcoal,
          selectedItemColor: AppColors.zestyLime,
          unselectedItemColor: Colors.white54,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed, // Needed for 4 items
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: 'Pantry'),
            BottomNavigationBarItem(
                icon: Icon(Icons.menu_book), label: 'Recipes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart), label: 'Cart'),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.zestyLime,
              child:
                  const Icon(Icons.camera_alt, color: AppColors.deepCharcoal),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
            )
          : null,
    );
  }

  Widget _buildHomeDashboard(WidgetRef ref) {
    return Column(
      children: [
        AppBar(
          title: const Text('ChefMind AI'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.link, color: AppColors.zestyLime),
              onPressed: _showUrlInputDialog,
            ),
            IconButton(
              icon: const Icon(Icons.diamond_outlined,
                  color: AppColors.zestyLime),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'What are we cooking?',
                  style: TextStyle(
                    color: AppColors.electricWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildSearchBar(ref),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isPantryMode = false; // Default: Discover Mode

  void _dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ... build method ...

  Widget _buildSearchBar(WidgetRef ref) {
    if (_isPantryMode) {
      return Column(
        children: [
          // Smart Toggle
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPantryMode = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isPantryMode
                            ? AppColors.zestyLime
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Discover 🌍",
                        style: TextStyle(
                            color: !_isPantryMode
                                ? AppColors.deepCharcoal
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPantryMode = true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isPantryMode
                            ? AppColors.zestyLime
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "My Pantry 🥬",
                        style: TextStyle(
                            color: _isPantryMode
                                ? AppColors.deepCharcoal
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // New Pantry Generator Widget
          PantryGeneratorWidget(
            onGenerate: () {
              // Switch to Recipes tab after generation starts
              setState(() => _currentIndex = 2);
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        // Smart Toggle
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPantryMode = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_isPantryMode
                          ? AppColors.zestyLime
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Discover 🌍",
                      style: TextStyle(
                          color: !_isPantryMode
                              ? AppColors.deepCharcoal
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPantryMode = true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isPantryMode
                          ? AppColors.zestyLime
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "My Pantry 🥬",
                      style: TextStyle(
                          color: _isPantryMode
                              ? AppColors.deepCharcoal
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Discover Search UI
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.zestyLime),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Healthy protein snack...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) => _performSearch(ref, value),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () => setState(() => _searchController.clear()),
                ),
              PulseMicrophoneButton(
                onResult: (text) {
                  setState(() {
                    _searchController.text = text;
                  });
                },
                onlisteningStart: () {},
                onListeningEnd: () {
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(ref, _searchController.text);
                  }
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _performSearch(ref, _searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zestyLime,
                foregroundColor: AppColors.deepCharcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Generate with AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  void _performSearch(WidgetRef ref, String query) {
    if (query.trim().isEmpty) return;

    // Logic Branching
    if (_isPantryMode) {
      // Pantry Mode: Use pantry items + query context
      ref.read(recipeControllerProvider.notifier).generate(
            mode: 'pantry_chef',
            query: query,
          );
    } else {
      // Discover Mode: Pure generation
      ref.read(recipeControllerProvider.notifier).generate(
            mode: 'discover',
            query: query,
          );
    }

    // Switch to Recipes tab
    setState(() => _currentIndex = 2);
  }

  void _showUrlInputDialog() {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Import from Link",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Paste recipe URL here...",
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.zestyLime),
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context); // Close dialog
                // Trigger Import
                ref.read(importControllerProvider.notifier).analyzeLink(url);
                // Optional: Navigate to recipes tab or show loading?
                // The import controller usually handles navigation or toast.
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.zestyLime,
              foregroundColor: AppColors.deepCharcoal,
            ),
            child: const Text("Import"),
          )
        ],
      ),
    );
  }
}
