import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/liquid_mesh_background.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'subscription_controller.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/config/store_config.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = false;
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    try {
      final offerings = await ref
          .read(subscriptionControllerProvider.notifier)
          .fetchOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
        });
      }
    } catch (e) {
      debugPrint("Error fetching offerings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionControllerProvider);
    final currentTier =
        subscriptionState.valueOrNull ?? SubscriptionTier.homeCook;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background
          const LiquidMeshBackground(),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    children: [
                      _buildBillingToggle(context),
                      const SizedBox(height: 32),
                      // Plan 1: Home Cook
                      _buildPlanCard(
                        context: context,
                        tier: SubscriptionTier.homeCook,
                        title:
                            AppLocalizations.of(context)!.subscriptionHomeCook,
                        price: AppLocalizations.of(context)!
                            .subscriptionFreeForever,
                        features: [
                          AppLocalizations.of(context)!
                              .subscriptionAIRecipesDay,
                          AppLocalizations.of(context)!
                              .subscriptionSave3Favorites,
                          AppLocalizations.of(context)!
                              .subscriptionLinkBookmarking,
                          AppLocalizations.of(context)!
                              .subscriptionDailyLinkShares,
                        ],
                        defaultButtonText:
                            AppLocalizations.of(context)!.subscriptionDowngrade,
                        isCurrent: currentTier == SubscriptionTier.homeCook,
                        checkColor: Colors.grey,
                        buttonColor: Colors.white12,
                      ),
                      const SizedBox(height: 24),

                      // Plan 2: Sous Chef (Hero)
                      _buildPlanCard(
                        context: context,
                        tier: SubscriptionTier.sousChef,
                        title:
                            AppLocalizations.of(context)!.subscriptionSousChef,
                        price: _isYearly ? '\$7.99 / mo' : '\$9.99 / mo',
                        billingNote: _isYearly
                            ? AppLocalizations.of(context)!
                                .subscriptionBilledYearly('\$95.88')
                            : null,
                        features: [
                          AppLocalizations.of(context)!.subscriptionUnlimitedAI,
                          AppLocalizations.of(context)!
                              .subscriptionFullLinkScraper,
                          AppLocalizations.of(context)!
                              .subscriptionUnlimitedVault,
                          AppLocalizations.of(context)!
                              .subscriptionUnlimitedSharing,
                          AppLocalizations.of(context)!
                              .subscriptionAdvancedDietary,
                        ],
                        defaultButtonText: currentTier ==
                                SubscriptionTier.executiveChef
                            ? AppLocalizations.of(context)!
                                .subscriptionDowngradeTo(
                                    AppLocalizations.of(context)!
                                        .subscriptionSousChef)
                            : AppLocalizations.of(context)!
                                .subscriptionUpgradeTo(
                                    AppLocalizations.of(context)!
                                        .subscriptionSousChef),
                        isPopular: true,
                        isCurrent: currentTier == SubscriptionTier.sousChef,
                        checkColor: AppColors.zestyLime,
                        titleColor: AppColors.zestyLime,
                        buttonColor: AppColors.zestyLime,
                        buttonTextColor: Colors.black,
                      ),
                      const SizedBox(height: 24),

                      // Plan 3: Executive Chef
                      _buildPlanCard(
                        context: context,
                        tier: SubscriptionTier.executiveChef,
                        title: AppLocalizations.of(context)!
                            .subscriptionExecutiveChef,
                        price: _isYearly ? '\$15.99 / mo' : '\$19.99 / mo',
                        billingNote: _isYearly
                            ? AppLocalizations.of(context)!
                                .subscriptionBilledYearly('\$191.88')
                            : null,
                        features: [
                          AppLocalizations.of(context)!.subscriptionHighSpeedAI,
                          AppLocalizations.of(context)!
                              .subscriptionMoodSuggestions,
                          AppLocalizations.of(context)!.subscriptionFamilySync,
                          AppLocalizations.of(context)!
                              .subscriptionPriorityAccess,
                        ],
                        defaultButtonText: AppLocalizations.of(context)!
                            .subscriptionGoExecutive,
                        isCurrent:
                            currentTier == SubscriptionTier.executiveChef,
                        checkColor: AppColors.zestyLime,
                        hasGlowBorder: true,
                        isSerif: true,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            AppLocalizations.of(context)!.subscriptionTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: _restorePurchases,
            child: const Text("Restore",
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleOption(
              AppLocalizations.of(context)!.subscriptionMonthly,
              !_isYearly,
              () => setState(() => _isYearly = false),
            ),
            _buildToggleOption(
              AppLocalizations.of(context)!.subscriptionYearlySave,
              _isYearly,
              () => setState(() => _isYearly = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required SubscriptionTier tier,
    required String title,
    required String price,
    String? billingNote,
    required List<String> features,
    required String defaultButtonText, // Renamed from buttonText
    bool isPopular = false,
    bool isCurrent = false,
    bool hasGlowBorder = false,
    Color checkColor = Colors.white,
    Color titleColor = Colors.white,
    Color? buttonColor,
    Color buttonTextColor = Colors.white,
    bool isSerif = false,
    bool forceGhost = false,
  }) {
    // Determine Button State
    final String buttonText = isCurrent
        ? AppLocalizations.of(context)!.subscriptionCurrentPlan
        : defaultButtonText;
    final bool isGhost =
        isCurrent || forceGhost; // Current plan always shows as Ghost button

    // Scale and Border Logic (Now based on isCurrent instead of selection)
    final double scale = isCurrent ? 1.05 : 1.0;
    final BorderSide borderSide = (isCurrent || hasGlowBorder)
        ? BorderSide(
            color: AppColors.zestyLime.withOpacity(isCurrent ? 0.8 : 0.5),
            width: isCurrent ? 2 : 1)
        : BorderSide(color: Colors.white.withOpacity(0.1));

    final BoxShadow? glowShadow = (isCurrent || hasGlowBorder)
        ? BoxShadow(
            color: AppColors.zestyLime.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          )
        : null;

    final titleStyle = isSerif
        ? GoogleFonts.playfairDisplay(
            color: titleColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          )
        : GoogleFonts.inter(
            color: titleColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      transform: Matrix4.identity()..scale(scale),
      transformAlignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass Container
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.deepCharcoal.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.fromBorderSide(borderSide),
                boxShadow: glowShadow != null ? [glowShadow] : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    title,
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Price
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (billingNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      billingNote,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Features
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Icon(Icons.check, color: checkColor, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                f,
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  // Button
                  _buildActionButton(
                    context: context,
                    text: buttonText,
                    isGhost: isGhost,
                    color: buttonColor,
                    textColor: buttonTextColor,
                    onTap: () {
                      if (isCurrent) return;
                      _handlePayment(context, tier);
                    },
                  ),
                ],
              ),
            ),
          ),
          // Most Popular Ribbon
          if (isPopular)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.zestyLime,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Text(
                  'MOST POPULAR',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String text,
    required bool isGhost,
    Color? color,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    if (isGhost) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white30),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight
                    .bold)), // Force white text for ghost because "Current Plan" is usually neutral
      );
    }

    // ... rest of the method (Exec Logic)
    final isExecutive = text == 'Go Executive';
    if (isExecutive) {
      // ... existing executive logic
      return Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [
          BoxShadow(color: AppColors.zestyLime.withOpacity(0.2), blurRadius: 10)
        ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side:
                        const BorderSide(color: AppColors.zestyLime, width: 1)),
                elevation: 0,
              ),
              child: Text(text,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.zestyLime,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(text,
          style:
              GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _handlePayment(
      BuildContext context, SubscriptionTier tier) async {
    if (tier == SubscriptionTier.homeCook) {
      // Downgrades are handled by App Store management
      NanoToast.showInfo(context, "Manage downgrades in your Store settings.");
      return;
    }

    if (_offerings == null) {
      NanoToast.showError(
          context, "Store not configured. Please try again later.");
      return;
    }

    // Logic: Find package based on selected Tier and Interval (_isYearly)
    // We expect Offerings named 'sous_chef' and 'executive_chef' in RevenueCat
    // OR we use the 'current' offering and look for packages.
    // Let's assume the standard Setup: Offering 'default' -> Packages 'sous_monthly', 'sous_yearly' etc.
    // OR separate offerings per tier?
    // BEST PRACTICE: Use 'current' offering, allowing remote config change.
    // We need to match Entitlement to Package? No, Package -> Entitlement.
    // We will look for packages in 'current' offering with identifier containing key words?
    // Fragile.
    // Better: Look for offering with ID == entitlementID?
    // Let's assume standard Offering 'default'.
    final offering = _offerings?.current;
    if (offering == null) {
      NanoToast.showError(context, "No offers available.");
      return;
    }

    // Look for specific package based on tier & interval
    // We assume the packages in the Offering are keyed/identified clearly.
    // Helper to find package:
    Package? package;
    final targetEntitlement = tier == SubscriptionTier.executiveChef
        ? StoreConfig.entitlementExecutiveChef
        : StoreConfig.entitlementSousChef;

    // RevenueCat doesn't link Package -> Entitlement directly in SDK object easily without metadata.
    // Fallback: Check package identifier or product identifier.
    // convention: "$entitlement_$interval" e.g. "sous_chef_monthly"
    final interval = _isYearly ? "yearly" : "monthly";
    final targetId = "${targetEntitlement}_$interval";

    // Try to find a package where the identifier contains our target keywords
    try {
      package = offering.availablePackages.firstWhere(
        (p) =>
            p.storeProduct.identifier.contains(targetId) || // Store ID
            p.identifier.contains(targetId), // RC Package ID
      );
    } catch (_) {
      // Not found
    }

    if (package == null) {
      // Fallback for demo/dev if strict ID parsing fails
      // Just grab first monthly/yearly package? No that's dangerous.
      NanoToast.showError(context, "Product not found: $targetId");
      return;
    }

    try {
      await ref
          .read(subscriptionControllerProvider.notifier)
          .purchasePackage(package);
      if (context.mounted) {
        NanoToast.showSuccess(
            context, AppLocalizations.of(context)!.subscriptionPlanUpdated);
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
          // User cancelled, do nothing or show info
          // NanoToast.showInfo(context, "Purchase cancelled");
        } else {
          NanoToast.showError(context, "Purchase failed: ${e.message}");
        }
      }
    } catch (e) {
      if (context.mounted) {
        NanoToast.showError(context, "An unexpected error occurred.");
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await ref
          .read(subscriptionControllerProvider.notifier)
          .restorePurchases();
      if (mounted) {
        NanoToast.showSuccess(context, "Purchases restored!");
      }
    } catch (e) {
      if (mounted) {
        NanoToast.showError(context, "Restore failed.");
      }
    }
  }
}
