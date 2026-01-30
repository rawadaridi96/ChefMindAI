import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:intl/intl.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/features/subscription/presentation/subscription_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionDetailsScreen extends ConsumerStatefulWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  ConsumerState<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState
    extends ConsumerState<SubscriptionDetailsScreen> {
  CustomerInfo? _customerInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (mounted) {
        setState(() {
          _customerInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionControllerProvider);
    final tier = subState.valueOrNull ?? SubscriptionTier.homeCook;

    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
            AppLocalizations.of(context)?.settingsSubscriptionBilling ??
                "Subscription",
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildPlanCard(context, tier),
                  const SizedBox(height: 32),
                  if (tier != SubscriptionTier.homeCook) ...[
                    _buildDetailsList(),
                    const Spacer(),
                    _buildManageButton(),
                    const SizedBox(height: 20),
                  ] else ...[
                    const Spacer(),
                    _buildUpgradeButton(context),
                    const SizedBox(height: 20),
                  ]
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(BuildContext context, SubscriptionTier tier) {
    String title;
    String subtitle;
    Color color;

    switch (tier) {
      case SubscriptionTier.executiveChef:
        title = AppLocalizations.of(context)!.tierExecutiveChef;
        subtitle = "Ultimate Access";
        color = AppColors.zestyLime;
        break;
      case SubscriptionTier.sousChef:
        title = AppLocalizations.of(context)!.tierSousChef;
        subtitle = "Premium Access";
        color = AppColors.zestyLime;
        break;
      case SubscriptionTier.homeCook:
      default:
        title = AppLocalizations.of(context)!.tierHomeCook;
        subtitle = "Free Plan";
        color = Colors.white54;
        break;
    }

    return GlassContainer(
      borderRadius: 24,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.stars, color: color, size: 48),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsList() {
    if (_customerInfo == null) return const SizedBox.shrink();

    final entitlements = _customerInfo!.entitlements.active.values.toList();
    if (entitlements.isEmpty) return const SizedBox.shrink();

    final latest = entitlements.first; // Grab primary entitlement
    final date = latest.expirationDate;

    return Column(
      children: [
        _buildRow("Status", "Active", Colors.green),
        const Divider(color: Colors.white12),
        if (date != null)
          _buildRow("Renews / Expires",
              DateFormat.yMMMd().format(DateTime.parse(date)), Colors.white),
        const Divider(color: Colors.white12),
        _buildRow(
            "Platform",
            latest.store == Store.appStore ? "App Store" : "Play Store",
            Colors.white70),
      ],
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildManageButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () async {
          final Uri url =
              Uri.parse('https://apps.apple.com/account/subscriptions');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        child: const Text("Manage Subscription",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    // Logic for upgrade...
    return const SizedBox.shrink();
  }
}
