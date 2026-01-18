import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/widgets/liquid_mesh_background.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'subscription_controller.dart';
import 'currency_controller.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = false;
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
                      _buildBillingToggle(),
                      const SizedBox(height: 32),
                      // Plan 1: Home Cook
                      _buildPlanCard(
                        tier: SubscriptionTier.homeCook,
                        title: 'Home Cook',
                        price: 'Free Forever',
                        features: [
                          '5 Curated AI Recipes/day',
                          'Save 3 Favorites',
                          'Basic Visuals'
                        ],
                        defaultButtonText: 'Downgrade',
                        isCurrent: currentTier == SubscriptionTier.homeCook,
                        checkColor: Colors.grey,
                        buttonColor: Colors.white12,
                      ),
                      const SizedBox(height: 24),

                      // Plan 2: Sous Chef (Hero)
                      _buildPlanCard(
                        tier: SubscriptionTier.sousChef,
                        title: 'Sous Chef',
                        price: _isYearly ? '\$7.99 / mo' : '\$9.99 / mo',
                        billingNote: _isYearly ? 'Billed \$95.88 yearly' : null,
                        features: [
                          'Unlimited Pantry AI',
                          'Full Link Scraper',
                          'Unlimited Vault Saves',
                          'Advanced Dietary Intelligence'
                        ],
                        defaultButtonText:
                            currentTier == SubscriptionTier.executiveChef
                                ? 'Downgrade to Sous Chef'
                                : 'Upgrade to Sous Chef',
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
                        tier: SubscriptionTier.executiveChef,
                        title: 'Executive Chef',
                        price: _isYearly ? '\$15.99 / mo' : '\$19.99 / mo',
                        billingNote:
                            _isYearly ? 'Billed \$191.88 yearly' : null,
                        features: [
                          'High-Speed AI Generation',
                          'Mood-Based Suggestions',
                          'Family Sync (Kitchen Vault)',
                          'Priority Early Access'
                        ],
                        defaultButtonText: 'Go Executive',
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
          const Text(
            'Unlock the Kitchen',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
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
            _buildToggleOption('Monthly', !_isYearly),
            _buildToggleOption('Yearly (Save 20%)', _isYearly),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isYearly = text.contains('Yearly');
        });
      },
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
    final String buttonText = isCurrent ? 'Current Plan' : defaultButtonText;
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
    try {
      // Directly upgrade usage for now (as per user request to restore functionality)
      await ref.read(subscriptionControllerProvider.notifier).upgrade(tier);
      if (context.mounted) {
        NanoToast.showSuccess(context, 'Plan updated successfully!');
      }
    } catch (e) {
      if (context.mounted) {
        NanoToast.showError(context, 'Failed to update plan: $e');
      }
    }
  }
}
