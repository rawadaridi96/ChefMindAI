import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class GuideStep {
  final String title;
  final String description;
  final String? tip;
  final IconData icon;

  const GuideStep({
    required this.title,
    required this.description,
    this.tip,
    required this.icon,
  });
}

class GuideModule {
  final String title;
  final String description;
  final List<GuideStep> steps;

  const GuideModule({
    required this.title,
    required this.description,
    required this.steps,
  });
}

class GuideData {
  /// Returns localized guide modules based on the current context
  static List<GuideModule> getModules(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return [
      // 1. Discover & Create (Consolidated)
      GuideModule(
        title: l10n.guideDiscoverTitle,
        description: l10n.guideDiscoverDesc,
        steps: [
          GuideStep(
            title: l10n.guidePromptStep,
            description: l10n.guidePromptDesc,
            icon: LucideIcons.keyboard,
          ),
          GuideStep(
            title: l10n.guideFiltersStep,
            description: l10n.guideFiltersDesc,
            icon: LucideIcons.sliders,
          ),
          GuideStep(
            title: l10n.guideSwitchModeStep,
            description: l10n.guideSwitchModeDesc,
            icon: LucideIcons.arrowRightLeft,
          ),
          GuideStep(
            title: l10n.guidePantryLogicStep,
            description: l10n.guidePantryLogicDesc,
            icon: LucideIcons.filter,
          ),
          GuideStep(
            title: l10n.guideUnifiedGenerate,
            description: l10n.guideUnifiedGenerateDesc,
            icon: LucideIcons.wand2,
          ),
        ],
      ),
      // 2. The Vault
      GuideModule(
        title: l10n.guideVault,
        description: l10n.guideVaultDesc,
        steps: [
          GuideStep(
            title: l10n.guideDigitalCookbook,
            description: l10n.guideDigitalCookbookDesc,
            icon: LucideIcons.book,
          ),
          GuideStep(
            title: l10n.guideSmartSearch,
            description: l10n.guideSmartSearchDesc,
            icon: LucideIcons.search,
          ),
          GuideStep(
            title: l10n.guideVaultLinks,
            description: l10n.guideVaultLinksDesc,
            icon: LucideIcons.toggleRight,
          ),
          GuideStep(
            title: l10n.guideImportStep,
            description: l10n.guideImportStepDesc,
            icon: LucideIcons.downloadCloud,
          ),
          GuideStep(
            title: l10n.guideOfflineVault,
            description: l10n.guideOfflineVaultDesc,
            icon: LucideIcons.wifiOff,
          ),
        ],
      ),
      // 3. Pantry & Cart
      GuideModule(
        title: l10n.guidePantryCart,
        description: l10n.guidePantryCartDesc,
        steps: [
          GuideStep(
            title: l10n.guideStockUpStep,
            description: l10n.guideStockUpDesc,
            icon: LucideIcons.camera, // Keeping camera icon for scanner focus
          ),
          GuideStep(
            title: l10n.guideSmartMgmtStep,
            description: l10n.guideSmartMgmtDesc,
            icon: LucideIcons.refrigerator,
          ),
          GuideStep(
            title: l10n.guideShopListStep,
            description: l10n.guideShopListDesc,
            icon: LucideIcons.shoppingCart,
          ),
          GuideStep(
            title: l10n.guideOfflinePantry,
            description: l10n.guideOfflinePantryDesc,
            icon: LucideIcons.wifiOff,
          ),
        ],
      ),
      // 4. Cooking Tools
      GuideModule(
        title: l10n.guideCookingTools,
        description: l10n.guideCookingToolsDesc,
        steps: [
          GuideStep(
            title: l10n.guideScalingHow,
            description: l10n.guideScalingHowDesc,
            icon: LucideIcons.scale,
          ),
          GuideStep(
            title: l10n.guideCookingStart,
            description: l10n.guideCookingStartDesc,
            icon: LucideIcons.play,
          ),
          GuideStep(
            title: l10n.guideAssistantAsk,
            description: l10n.guideAssistantAskDesc,
            icon: LucideIcons.messageCircle,
          ),
        ],
      ),
      // 5. Family Sync
      GuideModule(
        title: l10n.guideFamilySync,
        description: l10n.guideFamilySyncDesc,
        steps: [
          GuideStep(
            title: l10n.guideRealtimeShop,
            description: l10n.guideRealtimeShopDesc,
            icon: LucideIcons.users,
          ),
          GuideStep(
            title: l10n.guideShareRecipes,
            description: l10n.guideShareRecipesDesc,
            icon: LucideIcons.share2,
          ),
          GuideStep(
            title: l10n.guideOfflineSync,
            description: l10n.guideOfflineSyncDesc,
            icon: LucideIcons.refreshCw,
          ),
        ],
      ),
      // 6. Subscription Plans
      GuideModule(
        title: l10n.guideSubscriptionPlans,
        description: l10n.guideSubscriptionPlansDesc,
        steps: [
          GuideStep(
            title: l10n.guideHomeCookTier,
            description: l10n.guideHomeCookTierDesc,
            icon: LucideIcons.home,
          ),
          GuideStep(
            title: l10n.guideSousChefTier,
            description: l10n.guideSousChefTierDesc,
            icon: LucideIcons.chefHat,
          ),
          GuideStep(
            title: l10n.guideExecutiveChefTier,
            description: l10n.guideExecutiveChefTierDesc,
            icon: LucideIcons.crown,
          ),
        ],
      ),
    ];
  }

  /// Legacy static accessor for backward compatibility (English only)
  @Deprecated('Use getModules(context) for localized content')
  static const List<GuideModule> modules = [];
}
