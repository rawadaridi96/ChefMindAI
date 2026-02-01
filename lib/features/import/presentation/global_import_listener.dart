import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/features/import/presentation/import_controller.dart';
import 'package:chefmind_ai/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:chefmind_ai/core/theme/app_theme.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/recipes/presentation/vault_controller.dart';
import '../../../../core/widgets/nano_toast.dart';
import '../../../../core/widgets/premium_paywall.dart';
import '../../../../core/exceptions/premium_limit_exception.dart';
import '../../recipes/data/vault_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class GlobalImportListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const GlobalImportListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  ConsumerState<GlobalImportListener> createState() =>
      _GlobalImportListenerState();
}

class _GlobalImportListenerState extends ConsumerState<GlobalImportListener> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller alive!
    ref.watch(importControllerProvider);

    // Listen to URL changes
    ref.listen(importUrlStateProvider, (previous, next) {
      if (next != null) {
        if (next.startsWith("ERROR:")) {
          final errorMsg = next.substring(6);
          _showSnackBar(errorMsg, Colors.red);
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next.startsWith("PREMIUM_LIMIT:")) {
          final code = next.substring(14);
          String message = code; // Fallback
          if (code == 'LINK_SCRAPER') {
            message = AppLocalizations.of(context)!.premiumLinkScraper;
          }

          // Show paywall
          final navContext = widget.navigatorKey.currentContext;
          if (navContext != null) {
            PremiumPaywall.show(navContext,
                message: message,
                featureName: "Link Scraper",
                ctaLabel: AppLocalizations.of(context)!
                    .premiumUpgradeToSousOrExecutive);
          }
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next.startsWith("SUCCESS:")) {
          final msg = next.substring(8);
          _showSnackBar(msg, AppColors.zestyLime);
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next.startsWith("SAVING:")) {
          _showSnackBar("Saving to Vault...", Colors.white54);
          // Do not clear, let the process finish
        } else if (next.startsWith("CONFIRM_LINK:")) {
          final raw = next.substring(13);
          String url = raw;
          String? thumbnail;
          String? title;

          if (raw.contains('|')) {
            final parts = raw.split('|');
            if (parts.isNotEmpty) url = parts[0];
            if (parts.length > 1 && parts[1].isNotEmpty) thumbnail = parts[1];
            if (parts.length > 2 && parts[2].isNotEmpty) title = parts[2];
          }

          _showSaveLinkDialog(url, thumbnail: thumbnail, title: title);
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next.startsWith("SHARED_PREVIEW:")) {
          final token = next.substring(15);
          _showSharedPreviewDialog(token);
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next.startsWith("IMPORT_STARTED")) {
          // Show toast that it started in background
          _showSnackBar("ChefMind is analyzing the recipe in the background!",
              AppColors.zestyLime);
          // We DO NOT clear here, as we wait for complete or error.
          // Actually, we should probably clear to avoid re-trigger if rebuilt,
          // but we rely on next event. Safe to clear?
          // If we clear, we won't see "IMPORT_COMPLETE" if it happens too fast?
          // No, these are stream events or notifier state changes.
          // If state is unique string, it works.
          // Let's clear to be safe, assuming controller sets a new state for complete.
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next == "IMPORT_COMPLETE") {
          // Add a small delay to allow the loading dialog to pop cleanly first
          // This prevents potential collisions where the context is unstable during the pop transition
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ref.read(importUrlStateProvider.notifier).clear();
              // Get the result
              final recipe = ref.read(importedRecipeResultProvider);
              if (recipe != null) {
                _showRecipeReadyDialog(recipe);
              } else {
                debugPrint(
                    "ERROR: Recipe result is null in GlobalImportListener");
                _showSnackBar("Error: Result lost.", Colors.red);
              }
            }
          });
        } else if (next == "IMPORT_COMPLETE_FG") {
          // Foreground import handled by ImportRecipeDialog. Do nothing.
        } else {
          _showImportDialog(next);
        }
      }
    });

    return widget.child;
  }

  void _showSnackBar(String message, Color color) {
    final navContext = widget.navigatorKey
        .currentContext; // Still needed for Loc, but might work for localizations if above invalid
    // If navContext is the Navigator, AppLocalizations should be found (inherited from MaterialApp).

    // Explicitly derive OverlayState
    final overlay = widget.navigatorKey.currentState?.overlay;

    if (navContext != null) {
      if (color == Colors.red) {
        NanoToast.showError(
            navContext, AppLocalizations.of(navContext)!.importError(message),
            overlay: overlay);
      } else if (color == AppColors.zestyLime) {
        NanoToast.showSuccess(navContext, message, overlay: overlay);
      } else {
        NanoToast.showInfo(navContext, message, overlay: overlay);
      }
    }
  }

  void _showImportDialog(String url) {
    ref.read(importUrlStateProvider.notifier).clear();

    // Use push directly to avoid Navigator.of(context) lookup failure
    widget.navigatorKey.currentState?.push(
      DialogRoute(
        context: widget.navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => _ImportDialog(url: url),
      ),
    );
  }

  void _showSaveLinkDialog(String url, {String? thumbnail, String? title}) {
    ref.read(importUrlStateProvider.notifier).clear();
    widget.navigatorKey.currentState?.push(
      DialogRoute(
        context: widget.navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) =>
            _SaveLinkDialog(url: url, thumbnail: thumbnail, title: title),
      ),
    );
  }

  void _showSharedPreviewDialog(String token) {
    ref.read(importUrlStateProvider.notifier).clear();
    widget.navigatorKey.currentState?.push(
      DialogRoute(
        context: widget.navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (context) => _SharedPreviewDialog(token: token),
      ),
    );
  }

  void _showRecipeReadyDialog(Map<String, dynamic> recipe) {
    // Clear result after consuming
    // ref.read(importedRecipeResultProvider.notifier).state = null; // Maybe keep it until dialog closed?

    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    // Direct navigation is often preferred if the user just started it.
    // But since it's background, maybe they navigated away.
    // Let's show a "Recipe Ready" toast that opens it, OR a dialog.
    // Dialog is intrusive but clear.

    // Use push directly
    widget.navigatorKey.currentState?.push(
      DialogRoute(
        context: widget.navigatorKey.currentContext!,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.deepCharcoal,
          title: const Text("Recipe Ready! 🍳",
              style: TextStyle(color: AppColors.zestyLime)),
          content: Text("ChefMind has finished analyzing a recipe.",
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              child: const Text("View",
                  style: TextStyle(
                      color: AppColors.zestyLime, fontWeight: FontWeight.bold)),
              onPressed: () {
                final nav = widget.navigatorKey.currentState!;
                nav.pop(); // Close dialog uses Navigator within dialog or use key
                // If we use nav.pop(), it pops top. Correct.

                nav.push(MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                        recipe: recipe, isSharedPreview: true)));
              },
            )
          ],
        ),
      ),
    );
  }
}

class _SharedPreviewDialog extends ConsumerStatefulWidget {
  final String token;
  const _SharedPreviewDialog({required this.token});

  @override
  ConsumerState<_SharedPreviewDialog> createState() =>
      _SharedPreviewDialogState();
}

class _SharedPreviewDialogState extends ConsumerState<_SharedPreviewDialog> {
  String _status = "Loading Shared Recipe...";

  @override
  void initState() {
    super.initState();
    _fetchAndOpen();
  }

  Future<void> _fetchAndOpen() async {
    try {
      final recipe =
          await ref.read(vaultRepositoryProvider).getSharedRecipe(widget.token);

      if (recipe != null) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          // Navigate to preview
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(
                      recipe: recipe, isSharedPreview: true)));
        }
      } else {
        if (mounted) {
          setState(() => _status = "Recipe not found or expired.");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error: $e");
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.deepCharcoal.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.zestyLime.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.zestyLime.withOpacity(0.2), blurRadius: 20)
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(
                  color: AppColors.zestyLime, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text("Shared Recipe",
                style: AppTheme.darkTheme.textTheme.headlineSmall
                    ?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(_status,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SaveLinkDialog extends ConsumerStatefulWidget {
  final String url;
  final String? thumbnail;
  final String? title;

  const _SaveLinkDialog({required this.url, this.thumbnail, this.title});

  @override
  ConsumerState<_SaveLinkDialog> createState() => _SaveLinkDialogState();
}

class _SaveLinkDialogState extends ConsumerState<_SaveLinkDialog> {
  final TextEditingController _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add Form validation
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.title != null) {
      _titleController.text = widget.title!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return; // Validate first

    setState(() => _isLoading = true);

    try {
      final title = _titleController.text.trim();
      await ref.read(vaultControllerProvider.notifier).saveLink(widget.url,
          title: title.isNotEmpty ? title : null, thumbnail: widget.thumbnail);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        Navigator.pop(context); // Close dialog
        NanoToast.showSuccess(context, l10n.toastLinkSaved);
      }
    } on PremiumLimitReachedException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog

        final l10n = AppLocalizations.of(context)!;
        String message = e.message;
        String title = e.featureName;

        if (e.type == PremiumLimitType.vaultFull) {
          title = l10n.premiumVaultFullTitle;
          message = l10n.premiumVaultFullMessage(e.limit ?? 0);
        }

        PremiumPaywall.show(context, message: message, featureName: title);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _isLoading = false);
        NanoToast.showError(context, l10n.toastErrorGeneric(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access Vault state for validation
    final vaultState = ref.read(vaultControllerProvider);
    final existingTitles = vaultState.valueOrNull
            ?.where((r) {
              final json = r['recipe_json'];
              if (json is Map) {
                return json['type'] == 'link';
              }
              return false;
            })
            .map((r) => r['title'] as String?)
            .where((t) => t != null)
            .map((t) => t!.toLowerCase())
            .toSet() ??
        {};

    if (_isLoading) {
      // Loader State (Mimics ImportDialog)
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: AppColors.deepCharcoal.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.zestyLime.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.zestyLime.withOpacity(0.2), blurRadius: 20)
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const SizedBox(
                height: 50,
                width: 50,
                child: CircularProgressIndicator(
                    color: AppColors.zestyLime, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text("Saving to Vault...",
                  style: AppTheme.darkTheme.textTheme.headlineSmall
                      ?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    // Input State
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.deepCharcoal.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Save Video Link",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Give it a name:",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a name";
                    }
                    if (existingTitles.contains(value.trim().toLowerCase())) {
                      return "Name already exists. Try '${value.trim()} 2'";
                    }
                    if (existingTitles
                        .contains(value.replaceAll(' ', '').toLowerCase())) {
                      // Extra check for spaceless match?
                      // Nah, simple check is fine.
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "e.g. Brownie Recipe",
                    hintStyle: const TextStyle(color: Colors.white38),
                    errorStyle: const TextStyle(color: AppColors.errorRed),
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: AppColors.zestyLime),
                        borderRadius: BorderRadius.circular(12)),
                    errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.errorRed),
                        borderRadius: BorderRadius.circular(12)),
                    focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.errorRed),
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal,
                      ),
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportDialog extends ConsumerStatefulWidget {
  final String url;
  const _ImportDialog({required this.url});

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  String _status = "Analyzing Recipe...";

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    // Navigate via Controller (Robust Multimodal Logic)
    ref.read(importControllerProvider.notifier).startImport(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for completion to close this dialog
    ref.listen(importUrlStateProvider, (previous, next) {
      if (next != null) {
        if (next.startsWith("IMPORT_COMPLETE") ||
            next.startsWith("SUCCESS") ||
            next.startsWith("ERROR")) {
          if (mounted) Navigator.pop(context);
        } else if (next.startsWith("SAVING:")) {
          setState(() => _status = "Saving...");
        } else if (next.startsWith("INFO:")) {
          setState(() => _status = next.substring(5));
        }
      }
    });

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.deepCharcoal.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.zestyLime.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.zestyLime.withOpacity(0.2), blurRadius: 20)
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(
                  color: AppColors.zestyLime, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text("Importing Recipe",
                style: AppTheme.darkTheme.textTheme.headlineSmall
                    ?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(_status,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(widget.url,
                style: const TextStyle(color: Colors.white30, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
