import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/nano_toast.dart';
import '../auth/presentation/auth_controller.dart';

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
import 'presentation/history_controller.dart';
import 'dart:ui'; // For ImageFilter

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Check for post-login message (e.g. "Welcome back")
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = ref.read(postLoginMessageProvider);
      if (msg != null && mounted) {
        NanoToast.showSuccess(context, msg);
        // Clear it so it doesn't show again on hot reload or re-mount
        ref.read(postLoginMessageProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(postLoginMessageProvider, (previous, next) {
      if (next != null) {
        NanoToast.showSuccess(context, next);
        ref.read(postLoginMessageProvider.notifier).state = null;
      }
    });

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
              heroTag: 'home_scan_fab',
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
          title: const BrandLogo(fontSize: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Streak System (Commented out for now)
            /*
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 4),
                  Text("3",
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            */
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
        Container(
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
        // _buildSkillBadges(), (Commented out for now)
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

        // History Button (Right Aligned)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _showHistorySheet(context, ref),
              icon: const Icon(Icons.history, size: 16, color: Colors.white38),
              label: const Text(
                "Recent",
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Discover Search UI
        GlassContainer(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
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
                  textCapitalization: TextCapitalization.sentences,
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
        // _buildSkillBadges(), (Gamification disabled)
      ],
    );
  }

  void _performSearch(WidgetRef ref, String query) {
    if (query.trim().isEmpty) {
      NanoToast.showInfo(context, "Tell me what to cook first! 🍳");
      return;
    }

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

    // Save to History
    ref.read(historyControllerProvider.notifier).addPrompt(query);

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

  Widget _buildSkillBadges() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Chef Skills",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBadgeItem("Sauce Master", Icons.waves, true),
              _buildBadgeItem("Bread Winner", Icons.bakery_dining, false),
              _buildBadgeItem("Grill Pro", Icons.outdoor_grill, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(String label, IconData icon, bool unlocked) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked
                ? AppColors.zestyLime.withOpacity(0.1)
                : Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(
                color: unlocked ? AppColors.zestyLime : Colors.white12),
          ),
          child: Icon(
            icon,
            color: unlocked ? AppColors.zestyLime : Colors.white24,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: unlocked ? Colors.white : Colors.white24,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showHistorySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F).withOpacity(0.8),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(24),
            child: Consumer(builder: (context, ref, child) {
              final historyAsync = ref.watch(historyControllerProvider);

              return historyAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white24)),
                error: (err, stack) => Center(
                    child: Text("Error: $err",
                        style: const TextStyle(color: Colors.red))),
                data: (history) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Recent Ideas",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          if (history.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                final backup = [...history];
                                ref
                                    .read(historyControllerProvider.notifier)
                                    .clearAll();
                                Navigator.pop(context); // Close sheet

                                // Show Undo SnackBar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF202020),
                                    content: const Text("History cleared",
                                        style: TextStyle(color: Colors.white)),
                                    action: SnackBarAction(
                                      label: "UNDO",
                                      textColor: const Color(
                                          0xFFD1FF26), // AppColors.zestyLime
                                      onPressed: () {
                                        ref
                                            .read(historyControllerProvider
                                                .notifier)
                                            .restore(backup);
                                      },
                                    ),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.redAccent.withOpacity(0.8),
                              ),
                              child: const Text("Clear All"),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: history.isEmpty
                            ? const Center(
                                child: Text(
                                  "No recent history",
                                  style: TextStyle(color: Colors.white24),
                                ),
                              )
                            : ListView.separated(
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white10),
                                itemBuilder: (context, index) {
                                  final prompt = history[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.schedule,
                                        color: Colors.white38, size: 20),
                                    title: Text(
                                      prompt,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _searchController.text = prompt;
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }
}
