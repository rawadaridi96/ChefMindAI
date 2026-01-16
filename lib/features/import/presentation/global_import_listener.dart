import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/features/import/presentation/import_controller.dart';
import 'package:chefmind_ai/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:chefmind_ai/core/theme/app_theme.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/recipes/presentation/vault_controller.dart';
import 'dart:ui'; // For default blur
import '../../../../core/widgets/nano_toast.dart';

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
        } else if (next.startsWith("SUCCESS:")) {
          final msg = next.substring(8);
          _showSnackBar(msg, AppColors.zestyLime);
          ref.read(importUrlStateProvider.notifier).clear();
        } else if (next.startsWith("SAVING:")) {
          _showSnackBar("Saving to Vault...", Colors.white54);
          // Do not clear, let the process finish
        } else if (next.startsWith("CONFIRM_LINK:")) {
          final url = next.substring(13);
          _showSaveLinkDialog(url);
          ref.read(importUrlStateProvider.notifier).clear();
        } else {
          _showImportDialog(next);
        }
      }
    });

    return widget.child;
  }

  void _showSnackBar(String message, Color color) {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext != null) {
      if (color == Colors.red) {
        NanoToast.showError(navContext, message);
      } else if (color == AppColors.zestyLime) {
        NanoToast.showSuccess(navContext, message);
      } else {
        NanoToast.showInfo(navContext, message);
      }
    }
  }

  void _showImportDialog(String url) {
    // Reset state so it doesn't re-trigger immediately if rebuilt
    // But be careful not to clear it too early or loop.
    // Ideally we clear it AFTER we are done or when dialog closes.
    // Let's clear it immediately to "consume" the event.
    ref.read(importUrlStateProvider.notifier).clear();

    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (context) => _ImportDialog(url: url),
    );
  }

  void _showSaveLinkDialog(String url) {
    ref.read(importUrlStateProvider.notifier).clear(); // Ensure cleared
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (context) => _SaveLinkDialog(url: url),
    );
  }
}

class _SaveLinkDialog extends ConsumerStatefulWidget {
  final String url;
  const _SaveLinkDialog({required this.url});

  @override
  ConsumerState<_SaveLinkDialog> createState() => _SaveLinkDialogState();
}

class _SaveLinkDialogState extends ConsumerState<_SaveLinkDialog> {
  final TextEditingController _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add Form validation
  bool _isLoading = false;

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
      await ref
          .read(vaultControllerProvider.notifier)
          .saveLink(widget.url, title: title.isNotEmpty ? title : null);

      if (mounted) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          NanoToast.showSuccess(context, "Link Saved to Vault! 📂");
        }
      }
    } catch (e) {
      if (mounted) {
        if (mounted) {
          setState(() => _isLoading = false);
          NanoToast.showError(context, "Error: $e");
        }
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
                      borderSide: const BorderSide(color: AppColors.zestyLime),
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
    try {
      final recipe = await importRecipeFromUrl(widget.url);
      if (recipe != null) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          // Navigate to detail screen
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: recipe)));
        }
      } else {
        if (mounted) {
          setState(() => _status = "Could not find a recipe.");
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
