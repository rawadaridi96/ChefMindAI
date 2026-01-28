import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/fun_loading_tips.dart';
import 'package:chefmind_ai/core/widgets/chefmind_watermark.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/nano_toast.dart';
import '../../../../core/widgets/network_error_view.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'import_recipe_dialog.dart';

import 'recipe_controller.dart';
import 'vault_controller.dart';
import 'recipe_detail_screen.dart';
import 'widgets/vault_recipe_card.dart'; // Keep this
import 'widgets/premium_recipe_card.dart'; // Add this
import '../../../../core/widgets/premium_paywall.dart';
import '../../../../core/exceptions/premium_limit_exception.dart';
import '../../settings/presentation/household_controller.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StreamSubscription _intentDataStreamSubscription;

  bool _showVaultLinks = false;

  // Vault Search State
  final TextEditingController _vaultSearchController = TextEditingController();
  bool _isGridView = false;
  String _vaultSearchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    _vaultSearchController.addListener(() {
      setState(() {
        _vaultSearchQuery = _vaultSearchController.text.toLowerCase().trim();
      });
    });

    // Share Intent Listener (Running App)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        // Typically URLs come as text/plain. Wait, 'getMediaStream' vs 'getMediaStream'?
        // The plugin changed in 1.8.x. Let's check docs logic.
        // Usually text shares come via text stream, but URL might be treated as text.
        // Let's print to debug.
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // For text/url shares (most common for social links)
    // Note: older versions used getTextStream, newer unifies or separates?
    // Let's assume standard separation for safety.
    // Actually, receive_sharing_intent ^1.8.1 uses `getMediaStream` for everything in newer generic types?
    // Wait, let's verify standard usage for URL. URLs usually come as Text.
    // I will try to listen to both or just text if available.
    // Checking pub.dev patterns... 1.8.1 has `getMediaStream` returning `SharedMediaFile` which contains path/type.
    // Usually URLs come as text/plain.

    // STARTUP Intent (Cold Start)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });

    // Stream (Background/Resume)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      _handleSharedFiles(value);
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });
  }

  // Deduplication state for share intents
  String? _lastSharedPath;
  DateTime? _lastSharedTime;

  void _handleSharedFiles(List<SharedMediaFile> files) {
    debugPrint("Trace: _handleSharedFiles called with ${files.length} files");
    // 1. Find text/url content
    final textFile = files.firstWhere(
        (f) => f.type == SharedMediaType.text || f.type == SharedMediaType.url,
        orElse: () => SharedMediaFile(path: '', type: SharedMediaType.text));

    if (textFile.path.isNotEmpty) {
      debugPrint("Trace: Processing share path: ${textFile.path}");
      // 2. Deduplication Check
      if (_lastSharedPath == textFile.path &&
          _lastSharedTime != null &&
          DateTime.now().difference(_lastSharedTime!) <
              const Duration(seconds: 3)) {
        debugPrint("Ignore: Duplicate share intent filtered: ${textFile.path}");
        return;
      }

      // 3. Update Tracker
      _lastSharedPath = textFile.path;
      _lastSharedTime = DateTime.now();

      // 4. Show Dialog
      _showImportDialog(textFile.path);
    } else {
      debugPrint("Trace: No text/url content found in share intent");
    }
  }

  void _showImportDialog([String? url]) async {
    debugPrint("Trace: _showImportDialog called. URL present: ${url != null}");
    final result = await showDialog(
      context: context,
      builder: (context) => ImportRecipeDialog(initialUrl: url),
    );

    debugPrint(
        "Trace: Import Dialog returned result type: ${result?.runtimeType}");

    if (result != null && result is Map<String, dynamic>) {
      // Navigate to details screen with the parsed recipe (unsaved)
      if (!mounted) return;
      debugPrint("Trace: Pushing RecipeDetailScreen from RecipesScreen");
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(
                  recipe: result,
                  isSharedPreview:
                      true, // We might need this flag to show 'Save' button instead of 'Edit'
                )),
      );
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _tabController.dispose();
    _vaultSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch state here to use isLoading in AppBar - REMOVED since BrandLogo is gone
    // final state = ref.watch(recipeControllerProvider);

    final isSyncEnabled = ref.watch(vaultSyncEnabledProvider);

    ref.listen(recipeControllerProvider, (previous, next) {
      // Auto-switch to Results tab IMMEDIATELY on start of generation (Loading)
      if (next.isLoading) {
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
        }
      }

      // Also ensure we stay there on completion (optional but good safety)
      else if (next.hasValue &&
          !next.hasError &&
          next.value != null &&
          next.value!.isNotEmpty) {
        if (previous?.isLoading == true && _tabController.index != 0) {
          _tabController.animateTo(0);
        }
      }

      if (next.hasError && !next.isLoading) {
        if (next.error is PremiumLimitReachedException) {
          final e = next.error as PremiumLimitReachedException;

          String message = e.message;
          String ctaLabel =
              AppLocalizations.of(context)!.premiumUpgradeToSousOrExecutive;

          switch (e.type) {
            case PremiumLimitType.vaultFull:
              message = AppLocalizations.of(context)!.premiumVaultFull;
              break;
            case PremiumLimitType.dailyShareLimit:
              message = AppLocalizations.of(context)!.premiumDailyShareLimit;
              break;
            case PremiumLimitType.executiveFeatureMood:
              message = AppLocalizations.of(context)!.premiumMoodExecutive;
              ctaLabel =
                  AppLocalizations.of(context)!.premiumUpgradeToExecutive;
              break;
            case PremiumLimitType.sousFeatureADI:
              message = AppLocalizations.of(context)!.premiumADISous;
              ctaLabel = AppLocalizations.of(context)!.premiumUpgradeToSous;
              break;
            case PremiumLimitType.dailyRecipeLimit:
              // Extract limit from original message if needed, or pass it via exception?
              // The exception message was constructed with $limit.
              // Ideally we pass limit in exception payload. For now, let's parse or use a generic one?
              // Or better, let's regex the number?
              // "You've reached your daily limit of 5 recipes."
              final limitMatch = RegExp(r'(\d+)').firstMatch(e.message);
              final limit = limitMatch?.group(1) ?? '5';
              message =
                  AppLocalizations.of(context)!.premiumDailyRecipeLimit(limit);
              break;
            default:
              // Fallback to existing logic if any
              if (e.featureName.contains('Executive')) {
                ctaLabel =
                    AppLocalizations.of(context)!.premiumUpgradeToExecutive;
              }
              break;
          }

          PremiumPaywall.show(
            context,
            message: message,
            featureName: e.featureName,
            ctaLabel: ctaLabel,
          );
        } else {
          if (NetworkErrorView.isNetworkError(next.error!)) {
            NanoToast.showError(
                context, "No connection. Please check your internet.");
          } else {
            NanoToast.showError(
                context, next.error.toString().replaceAll('Exception: ', ''));
          }
        }
      }
    });

    ref.listen(vaultControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        if (NetworkErrorView.isNetworkError(next.error!)) {
          NanoToast.showError(
              context, "No connection. Please check your internet.");
        } else {
          NanoToast.showError(
              context, next.error.toString().replaceAll('Exception: ', ''));
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: "import_fab_unique",
        // NEW: Import Button
        onPressed: () => _showImportDialog(),
        backgroundColor: AppColors.zestyLime,
        child: const Icon(Icons.add_link, color: AppColors.deepCharcoal),
      ),
      appBar: AppBar(
        // title: BrandLogo(...) -> Removed to save space
        title: SizedBox(
          height: 40,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.zestyLime,
            indicatorWeight: 3,
            labelColor: AppColors.zestyLime,
            unselectedLabelColor: Colors.white54,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            dividerColor: Colors.transparent, // Remove underlining divider
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            tabs: [
              Tab(text: AppLocalizations.of(context)!.recipesCurrentResults),
              Tab(text: AppLocalizations.of(context)!.recipesVault),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _tabController.index == 0
            ? null
            : IconButton(
                icon: Icon(
                  isSyncEnabled ? Icons.diversity_3 : Icons.person,
                  color: isSyncEnabled ? AppColors.zestyLime : Colors.white70,
                ),
                onPressed: () {
                  // 1. Check Household
                  final householdState = ref.read(householdControllerProvider);
                  if (householdState.valueOrNull == null) {
                    NanoToast.showInfo(context,
                        AppLocalizations.of(context)!.vaultJoinHousehold);
                    return;
                  }

                  ref.read(vaultSyncEnabledProvider.notifier).state =
                      !isSyncEnabled;
                },
                tooltip: isSyncEnabled
                    ? AppLocalizations.of(context)!.vaultViewingHousehold
                    : AppLocalizations.of(context)!.vaultViewingPersonal,
              ),
        actions: [
          if (isSyncEnabled && _tabController.index == 1)
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
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Premium Watermark
          const Positioned(
            left: -24,
            top: 76, // Compensate for TabBar height to match other screens
            bottom: 76,
            child: ChefMindWatermark(),
          ),
          // Content
          TabBarView(
            controller: _tabController,
            children: [
              _buildResults(),
              _buildVault(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final state = ref.watch(recipeControllerProvider);

    // Explicitly check for loading state to ensure the spinner is shown
    // even if we have previous data (e.g. valid reload).
    if (state.isLoading) {
      return const FunLoadingTips();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        // Results
        Expanded(
          child: state.when(
            data: (recipes) {
              if (recipes.isEmpty) {
                return Center(
                    child: Text(
                        AppLocalizations.of(context)!.recipesGenerateSomeMagic,
                        style: const TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];

                  final isLimitation = recipe['title'] == "Chef's Limitation";

                  if (isLimitation) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.zestyLime, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    recipe['title'] ?? 'Generic',
                                    style: const TextStyle(
                                        color: AppColors.zestyLime,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              recipe['description'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return PremiumRecipeCard(
                    recipe: recipe,
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailScreen(recipe: recipe)));
                    },
                  );
                },
              );
            },
            // On error, we just show the prompt again (toast handles the message)
            error: (e, s) {
              if (NetworkErrorView.isNetworkError(e)) {
                return NetworkErrorView(
                    onRetry: () => ref.invalidate(recipeControllerProvider));
              }
              return Center(
                  child: Text(
                      AppLocalizations.of(context)!.recipesGenerateSomeMagic,
                      style: const TextStyle(color: Colors.white54)));
            },
            loading: () => const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildVault() {
    final vaultState = ref.watch(vaultControllerProvider);
    final isSyncEnabled = ref.watch(vaultSyncEnabledProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(4),
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
          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // 1. Vault Filter Toggles (Primary)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(50), // Pill shape
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // RECIPES Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showVaultLinks = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_showVaultLinks
                              ? AppColors.zestyLime
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 18,
                                color: !_showVaultLinks
                                    ? Colors.black // Active text is black
                                    : Colors.white60),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.navRecipes,
                              style: TextStyle(
                                  color: !_showVaultLinks
                                      ? Colors.black
                                      : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // LINKS Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showVaultLinks = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _showVaultLinks
                              ? AppColors.zestyLime
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link,
                                size: 18,
                                color: _showVaultLinks
                                    ? Colors.black
                                    : Colors.white60),
                            const SizedBox(width: 8),
                            Text(
                              "Links",
                              style: TextStyle(
                                  color: _showVaultLinks
                                      ? Colors.black
                                      : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. HEADER: Search Icon + Grid Toggle (Secondary)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // Search Toggle Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                      if (!_isSearchVisible) {
                        _vaultSearchController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isSearchVisible
                          ? AppColors.zestyLime.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: _isSearchVisible
                          ? Border.all(color: AppColors.zestyLime, width: 1.5)
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Icon(
                      _isSearchVisible ? Icons.close : Icons.search,
                      color:
                          _isSearchVisible ? AppColors.zestyLime : Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                // Grid/List Toggle (Moved Here)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildViewToggle(
                          icon: Icons.grid_view_rounded,
                          isSelected: _isGridView,
                          onTap: () => setState(() => _isGridView = true)),
                      _buildViewToggle(
                          icon: Icons.view_list_rounded,
                          isSelected: !_isGridView,
                          onTap: () => setState(() => _isGridView = false)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. ANIMATED SEARCH BAR
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isSearchVisible
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08), // Sleek glass
                        borderRadius: BorderRadius.circular(25), // Pill shape
                        border: Border.all(
                            color: AppColors.zestyLime.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.zestyLime.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppColors.zestyLime, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _vaultSearchController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!
                                    .generalSearch, // "Search..."
                                hintStyle:
                                    const TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              autofocus: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.zestyLime,
              backgroundColor: AppColors.deepCharcoal,
              onRefresh: () async {
                ref.invalidate(vaultControllerProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: vaultState.when(
                data: (allRecipes) {
                  final recipes = allRecipes.where((r) {
                    final json = r['recipe_json'] ?? {};
                    final isLink = json['type'] == 'link';

                    // Filter by Type
                    if (_showVaultLinks && !isLink) return false;
                    if (!_showVaultLinks && isLink) return false;

                    // Filter by Search Query
                    if (_vaultSearchQuery.isNotEmpty) {
                      final title =
                          (json['title'] ?? '').toString().toLowerCase();
                      final platform =
                          (json['platform'] ?? '').toString().toLowerCase();

                      if (!title.contains(_vaultSearchQuery) &&
                          !platform.contains(_vaultSearchQuery)) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  if (recipes.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                              child: Text(
                                  _showVaultLinks
                                      ? AppLocalizations.of(context)!
                                          .vaultNoLinks
                                      : AppLocalizations.of(context)!
                                          .vaultNoRecipes,
                                  style:
                                      const TextStyle(color: Colors.white54))),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // View Toggle & Count (Formerly here, now removed toggle. Keeping Count?)
                      // Actually, let's keep a minimal "Count" row or integrate it.
                      // For "Slickness", maybe just a small caption text.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${recipes.length} ${recipes.length == 1 ? 'Item' : 'Items'}",
                            style: const TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      const SizedBox(height: 8),

                      Expanded(
                        child: _isGridView
                            ? GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: recipes.length,
                                itemBuilder: (context, index) {
                                  return _buildRecipeItem(
                                      context, recipes[index]);
                                },
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                itemCount: recipes.length,
                                itemBuilder: (context, index) {
                                  return _buildRecipeItem(
                                      context, recipes[index]);
                                },
                              ),
                      ),
                    ],
                  );
                },
                // On error, we just show the prompt again (toast handles the message)
                error: (e, s) {
                  if (NetworkErrorView.isNetworkError(e)) {
                    return NetworkErrorView(
                        onRetry: () => ref.refresh(vaultControllerProvider));
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                            child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.errorRed, size: 48),
                              const SizedBox(height: 16),
                              const Text("Oops! Couldn't load Vault.",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(e.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    ref.refresh(vaultControllerProvider),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.zestyLime,
                                    foregroundColor: AppColors.deepCharcoal),
                                child: const Text("Retry"),
                              )
                            ],
                          ),
                        )),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.zestyLime)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.zestyLime : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.deepCharcoal : Colors.white54,
        ),
      ),
    );
  }

  Widget _buildRecipeItem(BuildContext context, dynamic output) {
    final recipe = output['recipe_json'] ?? output;
    final isLink = recipe['type'] == 'link';

    return VaultRecipeCard(
      recipe: recipe,
      isGrid: _isGridView,
      deleteLabel: AppLocalizations.of(context)!.actionDelete,
      onDelete: () {
        // Existing delete confirmation logic
        _confirmDelete(output['recipe_id'], recipe['title'] ?? 'this item');
      },
      onTap: () {
        if (isLink) {
          // Smart Link Check: If we have ingredients, open Detail View
          if (recipe['ingredients'] != null &&
              (recipe['ingredients'] as List).isNotEmpty) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: recipe)));
          } else {
            // Standard Link: Launch URL
            final urlText = recipe['url'];
            if (urlText != null) {
              final uri = Uri.parse(urlText);
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: recipe)));
        }
      },
    );
  }

  Widget _buildMacroBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.electricWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(dynamic id, String title) async {
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String cleanTitle = title
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&#x2019;', "'")
            .replaceAll('&apos;', "'");
        final displayTitle = cleanTitle.length > 50
            ? '${cleanTitle.substring(0, 50)}...'
            : cleanTitle;
        return AlertDialog(
          backgroundColor: AppColors.deepCharcoal,
          title: Text(
              AppLocalizations.of(context)!
                  .vaultDeleteConfirmTitle(displayTitle),
              style: const TextStyle(color: Colors.white)),
          content: Text(AppLocalizations.of(context)!.vaultDeleteConfirmMessage,
              style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                  AppLocalizations.of(context)!.shoppingClearDialogCancel,
                  style: const TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppLocalizations.of(context)!.actionDelete,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ref.read(vaultControllerProvider.notifier).deleteRecipe(id);
      if (mounted) {
        NanoToast.showInfo(
            context, AppLocalizations.of(context)!.vaultRemovedToast);
      }
    }
  }
}
