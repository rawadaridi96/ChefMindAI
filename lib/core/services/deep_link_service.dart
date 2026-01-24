import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:chefmind_ai/core/widgets/payment_feedback_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'package:chefmind_ai/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:chefmind_ai/features/recipes/presentation/vault_controller.dart';
import 'package:chefmind_ai/core/exceptions/premium_limit_exception.dart';
import 'package:chefmind_ai/core/widgets/premium_paywall.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _appLinks = AppLinks();

    // Check initial link
    // _checkInitialLink(navigatorKey);

    // Listen for incoming links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri, navigatorKey);
    });
  }

  void _handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    debugPrint('Received Deep Link: $uri');

    // Handle Payment Success: chefmind://payment-success
    if (uri.scheme == 'chefmind' && uri.host == 'payment-success') {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // Show Success Modal
        PaymentFeedbackModal.show(context,
            isSuccess: true,
            message: "Thank you for subscribing! Your plan is now active.");
      }
    }

    // Handle Recipe Share: chefmind://share/recipe?id=...
    // Host: share, Path: /recipe
    if (uri.scheme == 'chefmind' &&
        uri.host == 'share' &&
        uri.path == '/recipe') {
      final recipeId = uri.queryParameters['id'];
      if (recipeId != null) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _handleRecipeDeepLink(context, recipeId);
        }
      }
    }

    // Handle Universal Share: chefmind://share/universal?token=...
    if (uri.scheme == 'chefmind' &&
        uri.host == 'share' &&
        uri.path == '/universal') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _handleUniversalDeepLink(context, token);
        }
      }
    }
  }

  Future<void> _handleRecipeDeepLink(
      BuildContext context, String recipeId) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppColors.zestyLime)),
    );

    try {
      // Access Provider Container
      final container = ProviderScope.containerOf(context, listen: false);
      final recipe = await container
          .read(vaultControllerProvider.notifier)
          .getRecipeById(recipeId);

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        if (recipe != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        } else {
          NanoToast.showError(context, "Recipe not found or access denied.");
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        NanoToast.showError(context, "Failed to load recipe: $e");
      }
    }
  }

  Future<void> _handleUniversalDeepLink(
      BuildContext context, String token) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppColors.zestyLime)),
    );

    try {
      // Access Provider Container
      final container = ProviderScope.containerOf(context, listen: false);
      final recipe = await container
          .read(vaultControllerProvider.notifier)
          .getSharedRecipe(token); // Use new method

      if (context.mounted) {
        // Do not pop yet, we try to save immediately

        if (recipe != null) {
          try {
            // Auto Save
            final savedRecipe = await container
                .read(vaultControllerProvider.notifier)
                .saveSharedRecipe(recipe);

            if (context.mounted) {
              Navigator.pop(context); // Close loading
              NanoToast.showSuccess(context, "Recipe saved to your Vault! 📥");

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => RecipeDetailScreen(
                    recipe: savedRecipe,
                    // isSharedPreview: false, // Default is false, it's saved now
                  ),
                ),
              );
            }
          } on PremiumLimitReachedException catch (e) {
            if (context.mounted) {
              Navigator.pop(context); // Close loading
              PremiumPaywall.show(context,
                  message: e.message, featureName: e.featureName);
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.pop(context); // Close loading
              NanoToast.showError(context, "Failed to save recipe: $e");
              // Option: Show it in preview mode if save failed?
              // For now, just error is safer/simpler as per request "automatically save".
              // If save fails due to other reasons (network?), maybe preview is nice,
              // but let's stick to the prompt.
            }
          }
        } else {
          Navigator.pop(context); // Close loading
          NanoToast.showError(context, "Link expired or invalid.");
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        NanoToast.showError(context, "Failed to load recipe: $e");
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
