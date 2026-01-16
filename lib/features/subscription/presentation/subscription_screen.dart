import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/services/payment_service.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:url_launcher/url_launcher.dart';
import 'subscription_controller.dart';
import 'currency_controller.dart';
import '../../../../core/widgets/nano_toast.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTier = ref.watch(subscriptionControllerProvider);

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background handled by parent or stack
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF202020), AppColors.deepCharcoal],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context)),
                      const Text('ChefMind Premium',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(currencyControllerProvider.notifier)
                              .toggleCurrency();
                        },
                        icon: const Icon(Icons.currency_exchange,
                            color: AppColors.zestyLime, size: 20),
                        label: Text(
                          ref.watch(currencyControllerProvider) ? 'USD' : 'NGN',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Unlock the Kitchen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your culinary level.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  _buildTierCard(
                    ref,
                    context,
                    tier: SubscriptionTier.free,
                    title: 'Free',
                    price: ref
                        .watch(currencyControllerProvider.notifier)
                        .formatPrice(0),
                    features: ['3 Manual Recipes/mo', 'Basic Visuals', 'Ads'],
                    current: currentTier == SubscriptionTier.free,
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    ref,
                    context,
                    tier: SubscriptionTier.pro,
                    title: 'Pro',
                    price:
                        '${ref.watch(currencyControllerProvider.notifier).formatPrice(12)} / mo',
                    rawPrice: 12.00,
                    variantId:
                        'ef95ee63-3c1c-49e0-a519-226f8489bd26', // TODO: Lemon Squeezy Variant ID
                    features: [
                      'Unlimited AI Scans',
                      'Pantry Tracking',
                      'Ad-free'
                    ],
                    current: currentTier == SubscriptionTier.pro,
                    isPopular: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTierCard(
                    ref,
                    context,
                    tier: SubscriptionTier.chef,
                    title: 'Chef',
                    price:
                        '${ref.watch(currencyControllerProvider.notifier).formatPrice(25)} / mo',
                    rawPrice: 25.00,
                    variantId:
                        '9fab7912-5357-4015-b0a9-55b28f644329', // TODO: Lemon Squeezy Variant ID
                    features: [
                      'Everything in Pro',
                      'Real-time Voice Assistant',
                      'Family Sharing'
                    ],
                    current: currentTier == SubscriptionTier.chef,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(
    WidgetRef ref,
    BuildContext context, {
    required SubscriptionTier tier,
    required String title,
    required String price,
    double? rawPrice,
    String? variantId,
    required List<String> features,
    required bool current,
    bool isPopular = false,
  }) {
    return GestureDetector(
      onTap: () async {
        if (tier == SubscriptionTier.free) {
          ref.read(subscriptionControllerProvider.notifier).upgrade(tier);
          NanoToast.showSuccess(context, 'Switched to $title Plan!');
          return;
        }

        // Lemon Squeezy Flow
        if (variantId != null) {
          final checkoutUrl = ref
              .read(paymentServiceProvider)
              .getCheckoutUrl(variantId, userEmail: "test@example.com");
          final uri = Uri.parse(checkoutUrl);

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri,
                mode: LaunchMode
                    .externalApplication); // Use external browser for secure checkout
          } else {
            if (context.mounted)
              NanoToast.showError(context, "Could not launch checkout");
          }
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: current ? AppColors.zestyLime : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    if (current)
                      const Icon(Icons.check_circle,
                          color: AppColors.zestyLime),
                  ],
                ),
                Text(price,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 24),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(f, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          if (isPopular && !current)
            Positioned(
              top: -12,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.zestyLime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Most Popular',
                    style: TextStyle(
                        color: AppColors.deepCharcoal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
