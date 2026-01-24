import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../recipes/presentation/vault_controller.dart';

part 'import_controller.g.dart';

@riverpod
class ImportController extends _$ImportController {
  StreamSubscription? _intentSub;
  String? _lastProcessedUrl;
  DateTime? _lastProcessedTime;

  // Background Processing State
  bool isImporting = false;
  bool _isBackgroundMode =
      true; // Default true. Explicit foreground sets false.

  @override
  void build() {
    // 3. Custom Method Channel for reliable Text Sharing (Bypassing plugin)
    // DISABLED for now
    /*
    const platform = MethodChannel('com.example.chefmind_ai/share');
    debugPrint("DEBUG: Setting up MethodChannel handler for 'com.example.chefmind_ai/share'");
    
    // ... (Code commented out as requested) ...
    */

    // Cleanup subscription (onDispose)
    ref.onDispose(() {
      _intentSub?.cancel();
    });
  }

  void analyzeLink(String text, {bool isBackground = true}) {
    _isBackgroundMode = isBackground;
    _extractAndImportUrl(text);
  }

  void switchToBackgroundMode() {
    _isBackgroundMode = true;
  }

  void _extractAndImportUrl(String sharedText) {
    debugPrint("Shared content received: $sharedText");

    // Check Subscription for Tier capabilities
    final canUseScraper =
        ref.read(subscriptionControllerProvider.notifier).canUseLinkScraper;

    // Robust Regex: Match http/https followed by non-whitespace characters
    final RegExp urlRegExp = RegExp(
      r'https?://\S+',
      caseSensitive: false,
    );

    final String? extractedUrl = urlRegExp.firstMatch(sharedText)?.group(0);

    if (extractedUrl != null) {
      // Deduplicate checks
      if (_lastProcessedUrl == extractedUrl &&
          _lastProcessedTime != null &&
          DateTime.now().difference(_lastProcessedTime!) <
              const Duration(seconds: 3)) {
        debugPrint("IGNORING DUPLICATE SHARE: $extractedUrl");
        return;
      }

      _lastProcessedUrl = extractedUrl;
      _lastProcessedTime = DateTime.now();

      // Check for Universal Share Deep Link
      // Format: chefmind://share/universal?token=...
      if (extractedUrl.contains('chefmind://share/universal') ||
          extractedUrl.contains('share/universal')) {
        final uri = Uri.parse(extractedUrl);
        final token = uri.queryParameters['token'];
        if (token != null) {
          // Navigate to Recipe Detail Screen with Token
          ref
              .read(importUrlStateProvider.notifier)
              .setUrl("SHARED_PREVIEW:$token");
          return;
        }
      }

      debugPrint("Extracted URL: $extractedUrl");

      if (canUseScraper) {
        // Paid User: Use AI Analysis (Background or Foreground based on flag)
        startImport(extractedUrl);
      } else {
        // Free User: Just Save Link
        _handleImport(extractedUrl);
      }
    } else {
      debugPrint("No URL found in: $sharedText");
      // Trigger a debug dialog to show the user what we received
      // Prefix with "ERROR:" to handle error state without complex object
      ref
          .read(importUrlStateProvider.notifier)
          .setUrl("ERROR:No URL found in: $sharedText");
    }
  }

  Future<void> _autoSaveLink(String url,
      {String? title, String? thumbnail}) async {
    try {
      // Show saving state (custom message handled by listener or generic)
      ref.read(importUrlStateProvider.notifier).setUrl("SAVING:Saving link...");

      // Default title if somehow null here, though caller should check
      final String finalTitle =
          (title != null && title.isNotEmpty) ? title : "Imported Link";

      await ref
          .read(vaultControllerProvider.notifier)
          .saveLink(url, title: finalTitle, thumbnail: thumbnail);

      ref
          .read(importUrlStateProvider.notifier)
          .setUrl("SUCCESS:Link Saved! 📥");
    } catch (e) {
      // If error (e.g. vault full), show error
      ref.read(importUrlStateProvider.notifier).setUrl(
          "ERROR:Failed to save: ${e.toString().replaceAll('Exception: ', '')}");
    }
  }

  Future<void> _handleImport(String url,
      {String? thumbnail, String? title}) async {
    // Trigger Confirm Dialog to ask for title. Append thumbnail/title if present.
    // Format: CONFIRM_LINK:url|thumbnail|title
    String stateData = "CONFIRM_LINK:$url|${thumbnail ?? ''}|${title ?? ''}";
    ref.read(importUrlStateProvider.notifier).setUrl(stateData);
  }

  // Renamed from startBackgroundImport to startImport as it handles both
  Future<void> startImport(String url) async {
    if (isImporting) return;

    // Notify UI that it started
    isImporting = true;
    ref.read(importUrlStateProvider.notifier).setUrl("IMPORT_STARTED");

    // Check Executive Status
    final isExecutive = ref.read(subscriptionControllerProvider).valueOrNull ==
        SubscriptionTier.executiveChef;

    try {
      final result = await importRecipeFromUrl(url, isExecutive: isExecutive);
      debugPrint(
          "Trace: startImport result received. IsNull: ${result == null}");

      if (result != null) {
        final status = result['status'] as String?;
        final recipe = result['recipe'] as Map<String, dynamic>?;
        final metadata = result['metadata'] as Map<String, dynamic>?;

        debugPrint(
            "Trace: Import Status: $status, HasRecipe: ${recipe != null}");

        final fallbackTitle = metadata?['title'] as String?;
        final thumbnail = metadata?['thumbnail'] as String?;

        if (status == 'found' && recipe != null) {
          // Success: Show Recipe
          // Ensure thumbnail is attached if missing in recipe
          if (recipe['thumbnail'] == null && thumbnail != null) {
            recipe['thumbnail'] = thumbnail;
          }
          // Inject Source URL for "Watch Video" feature
          recipe['url'] = url;

          ref.read(importedRecipeResultProvider.notifier).state = recipe;

          debugPrint(
              "Trace: Setting success state. BackgroundMode: $_isBackgroundMode");
          if (_isBackgroundMode) {
            ref.read(importUrlStateProvider.notifier).setUrl("IMPORT_COMPLETE");
          } else {
            ref
                .read(importUrlStateProvider.notifier)
                .setUrl("IMPORT_COMPLETE_FG");
          }
        } else {
          // Empty/Partial/Link Mode
          debugPrint("Recipe not found or empty. Saving as link.");
          ref
              .read(importUrlStateProvider.notifier)
              .setUrl("INFO:No recipe found. Saving link...");

          // Small delay for UI update
          await Future.delayed(const Duration(seconds: 1));
          await _autoSaveLink(url, title: fallbackTitle, thumbnail: thumbnail);
        }
      } else {
        // Null result? Fallback to manual save.
        await _handleImport(url);
      }
    } catch (e) {
      ref
          .read(importUrlStateProvider.notifier)
          .setUrl("ERROR:${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      isImporting = false;
    }
  }

  // Logic to actually import
  Future<Map<String, dynamic>?> importRecipeFromUrl(String url,
      {bool isExecutive = false}) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'import-recipe',
        body: {
          'url': url,
          'is_executive': isExecutive,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to import recipe: ${response.status}');
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // DEBUG LOGGING FOR IMAGE ISSUES
        debugPrint("--- IMPORT DEBUG START ---");
        if (data.containsKey('debug')) {
          debugPrint("SERVER LOGS: ${data['debug']}");
        }
        debugPrint("METADATA THUMB: ${data['metadata']?['thumbnail']}");
        if (data['recipe'] != null) {
          debugPrint("RECIPE THUMB: ${data['recipe']?['thumbnail']}");
        }
        debugPrint("--- IMPORT DEBUG END ---");

        return data;
      }
      return null;
    } catch (e) {
      debugPrint("EDGE FUNCTION ERROR: $e");
      if (e is FunctionException) {
        debugPrint("DETAILS: ${e.details}");
        throw Exception("Import Failed: ${e.details ?? e.toString()}");
      }
      rethrow;
    }
  }

  bool _isRecipeQualityAcceptable(Map<String, dynamic> recipe) {
    // Server now handles this, but keeping as a sanity check if needed.
    // For now, we trust the 'status' from server.
    return true;
  }
}

// Holder for the result
final importedRecipeResultProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

// Separate state provider for the import URL to trigger UI
@riverpod
class ImportUrlState extends _$ImportUrlState {
  @override
  String? build() => null;

  void setUrl(String url) => state = url;
  void clear() => state = null;
}
