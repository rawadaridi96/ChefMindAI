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
      GuideModule(
        title: l10n.guideQuickStart,
        description: l10n.guideQuickStartDesc,
        steps: [
          GuideStep(
            title: l10n.guideOpenDiscover,
            description: l10n.guideOpenDiscoverDesc,
            icon: LucideIcons.compass,
          ),
          GuideStep(
            title: l10n.guideEnterPrompt,
            description: l10n.guideEnterPromptDesc,
            icon: LucideIcons.keyboard,
          ),
          GuideStep(
            title: l10n.guideGenerateMagic,
            description: l10n.guideGenerateMagicDesc,
            tip: l10n.guideGenerateMagicTip,
            icon: LucideIcons.wand2,
          ),
        ],
      ),
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
            title: l10n.guideStorageLimits,
            description: l10n.guideStorageLimitsDesc,
            icon: LucideIcons.hardDrive,
          ),
          GuideStep(
            title: l10n.guideSmartSearch,
            description: l10n.guideSmartSearchDesc,
            icon: LucideIcons.history,
          ),
        ],
      ),
      GuideModule(
        title: l10n.guidePantryCart,
        description: l10n.guidePantryCartDesc,
        steps: [
          GuideStep(
            title: l10n.guidePantryTracking,
            description: l10n.guidePantryTrackingDesc,
            icon: LucideIcons.refrigerator,
          ),
          GuideStep(
            title: l10n.guideSmartCart,
            description: l10n.guideSmartCartDesc,
            icon: LucideIcons.shoppingCart,
          ),
          GuideStep(
            title: l10n.guideEasyAdjustments,
            description: l10n.guideEasyAdjustmentsDesc,
            icon: LucideIcons.plusCircle,
          ),
        ],
      ),
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
        ],
      ),
    ];
  }

  /// Legacy static accessor for backward compatibility (English only)
  @Deprecated('Use getModules(context) for localized content')
  static const List<GuideModule> modules = [];
}
