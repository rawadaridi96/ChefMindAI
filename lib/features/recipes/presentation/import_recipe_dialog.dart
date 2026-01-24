import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/import/presentation/import_controller.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';

class ImportRecipeDialog extends ConsumerStatefulWidget {
  final String? initialUrl;

  const ImportRecipeDialog({super.key, this.initialUrl});

  @override
  ConsumerState<ImportRecipeDialog> createState() => _ImportRecipeDialogState();
}

class _ImportRecipeDialogState extends ConsumerState<ImportRecipeDialog> {
  late TextEditingController _urlController;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _startImport();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ChefMind AI...';
    });

    // Trigger Controller
    // This will eventually update the state to IMPORT_STARTED (Paid) or CONFIRM_LINK (Free)
    // Trigger Controller
    // This will eventually update the state to IMPORT_STARTED (Paid) or CONFIRM_LINK (Free)
    // Explicitly set as Foreground so GlobalListener ignores it
    ref
        .read(importControllerProvider.notifier)
        .analyzeLink(url, isBackground: false);

    // We DO NOT pop here anymore. We wait for the listener or user action.
  }

  void _runInBackground() {
    ref.read(importControllerProvider.notifier).switchToBackgroundMode();
    Navigator.pop(context);
    NanoToast.showInfo(context, "Running in background...");
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Close Events
    ref.listen(importUrlStateProvider, (previous, next) {
      debugPrint("Trace: ImportRecipeDialog Listener received: $next");
      if (next != null) {
        if (next.startsWith("IMPORT_COMPLETE") ||
            next.startsWith("CONFIRM_LINK") ||
            next.startsWith("PREMIUM_LIMIT") ||
            next.startsWith("SUCCESS")) {
          if (mounted) {
            if (next == "IMPORT_COMPLETE") {
              debugPrint("Trace: Matching IMPORT_COMPLETE");
              final recipe = ref.read(importedRecipeResultProvider);
              debugPrint("Trace: Popping dialog with recipe... RootNav: true");
              Navigator.of(context, rootNavigator: true).pop(recipe);
            } else if (next == "IMPORT_COMPLETE_FG") {
              debugPrint("Trace: Matching IMPORT_COMPLETE_FG");
              final recipe = ref.read(importedRecipeResultProvider);
              debugPrint(
                  "Trace: Popping dialog with recipe (FG)... RootNav: true");
              Navigator.of(context, rootNavigator: true).pop(recipe);
            } else if (next.startsWith("SUCCESS")) {
              // Provide a signal to refresh or just nothing?
              // If we return just "SUCCESS" string, RecipesScreen ignores it (is Map check).
              // We should probably just pop.
              Navigator.of(context, rootNavigator: true).pop();
            } else {
              Navigator.of(context, rootNavigator: true).pop(next);
            }
          }
        } else if (next.startsWith("SAVING:")) {
          setState(() {
            _statusMessage = next.substring(7);
          });
        }
        if (next.startsWith("ERROR:")) {
          if (mounted) Navigator.pop(context); // Or show error in dialog?
        }
      }
    });

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Import Recipe",
              style: TextStyle(
                  color: AppColors.zestyLime,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              const CircularProgressIndicator(color: AppColors.zestyLime),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ).animate(onPlay: (c) => c.repeat()).shimmer(
                  duration: 2000.ms,
                  color: AppColors.zestyLime.withOpacity(0.5)),
              const SizedBox(height: 24),
            ] else ...[
              const Text(
                "Paste a link from Instagram, TikTok, or YouTube to extract the recipe using AI.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "https://...",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _startImport(),
              ),
              if (_statusMessage.startsWith('Error'))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                        color: AppColors.errorRed, fontSize: 13),
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
                    onPressed: _startImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.zestyLime,
                      foregroundColor: AppColors.deepCharcoal,
                    ),
                    child: const Text("Import"),
                  ),
                ],
              )
            ],
          ],
        ),
      ),
    );
  }
}
