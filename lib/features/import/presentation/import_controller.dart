import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../subscription/presentation/subscription_controller.dart';

part 'import_controller.g.dart';

@riverpod
class ImportController extends _$ImportController {
  StreamSubscription? _intentSub;
  String? _lastProcessedUrl;
  DateTime? _lastProcessedTime;

  @override
  void build() {
    // 1. Listen to 'receive_sharing_intent'
    // Note: In v1.8.1, all shares (text/url included) come through getMediaStream
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
      // DEBUG: Show exactly what we received
      if (value.isEmpty) {
        ref
            .read(importUrlStateProvider.notifier)
            .setUrl("ERROR:Received EMPTY media list");
      } else {
        final firstPath = value.first.path;
        // ref.read(importUrlStateProvider.notifier).setUrl("ERROR:Received: $firstPath"); // Optional: Uncomment to see raw text
        _extractAndImportUrl(firstPath);
      }
    }, onError: (err) {
      ref
          .read(importUrlStateProvider.notifier)
          .setUrl("ERROR:Stream Error: $err");
    });

    // Initial intent
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _extractAndImportUrl(value.first.path);
      }
      // Note: Not showing error for initial empty as it triggers on normal launch
    });

    // 3. Custom Method Channel for reliable Text Sharing (Bypassing plugin)
    // 3. Custom Method Channel for reliable Text Sharing (Bypassing plugin)
    const platform = MethodChannel('com.example.chefmind_ai/share');
    debugPrint(
        "DEBUG: Setting up MethodChannel handler for 'com.example.chefmind_ai/share'");

    platform.setMethodCallHandler((call) async {
      debugPrint("DEBUG: MethodChannel received call: ${call.method}");
      if (call.method == "shareText") {
        final String sharedText = call.arguments as String;
        debugPrint("DEBUG: MethodChannel payload: $sharedText");

        if (sharedText.isNotEmpty) {
          _extractAndImportUrl(sharedText);
        } else {
          ref
              .read(importUrlStateProvider.notifier)
              .setUrl("ERROR:Received empty text from MethodChannel");
        }
      }
    });

    // Check initial share from custom channel
    // Check initial share from custom channel
    try {
      platform.invokeMethod("getSharedText").then((value) {
        debugPrint("DEBUG: Initial getSharedText result: $value");
        if (value != null && value is String && value.isNotEmpty) {
          _extractAndImportUrl(value);
        }
      }).catchError((e) {
        // Suppress MissingPluginException on iOS Simulator or real devices without native impl
        if (e is MissingPluginException) {
          debugPrint("Custom Share Channel not implemented: ${e.message}");
        } else {
          debugPrint("Custom Share Channel Error: $e");
        }
      });
    } catch (e) {
      debugPrint("Custom Share Channel Init Error: $e");
    }

    // Cleanup subscription (onDispose)
    ref.onDispose(() {
      _intentSub?.cancel();
      // Clear method call handler
      platform.setMethodCallHandler(null);
    });
  }

  void analyzeLink(String text) {
    _extractAndImportUrl(text);
  }

  void _extractAndImportUrl(String sharedText) {
    debugPrint("Shared content received: $sharedText");

    // Enforce Subscription Limit for Scraper
    final canUseScraper =
        ref.read(subscriptionControllerProvider.notifier).canUseLinkScraper;
    if (!canUseScraper) {
      // We can't throw here because this is a void method called from a stream listener
      // So we set a special state that the UI (ImportOverlay or similar) must listen for.
      // OR better, we use the URL state to trigger the Paywall?
      // "ERROR:Link Scraper..." was used before.
      // Let's keep using the state but with a specific prefix that the UI can catch to show the sheet.
      ref
          .read(importUrlStateProvider.notifier)
          .setUrl("PREMIUM_LIMIT:Link Scraper is a Sous Chef feature.");
      return;
    }

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
      _handleImport(extractedUrl);
    } else {
      debugPrint("No URL found in: $sharedText");
      // Trigger a debug dialog to show the user what we received
      // Prefix with "ERROR:" to handle error state without complex object
      ref
          .read(importUrlStateProvider.notifier)
          .setUrl("ERROR:No URL found in: $sharedText");
    }
  }

  Future<void> _handleImport(String url) async {
    // Trigger Confirm Dialog to ask for title
    ref.read(importUrlStateProvider.notifier).setUrl("CONFIRM_LINK:$url");
  }
}

// Separate state provider for the import URL to trigger UI
@riverpod
class ImportUrlState extends _$ImportUrlState {
  @override
  String? build() => null;

  void setUrl(String url) => state = url;
  void clear() => state = null;
}

// Logic to actually import
Future<Map<String, dynamic>?> importRecipeFromUrl(String url) async {
  final response = await Supabase.instance.client.functions.invoke(
    'import-recipe',
    body: {'url': url},
  );

  if (response.status != 200) {
    throw Exception('Failed to import recipe: ${response.status}');
  }

  final data = response.data;
  if (data is Map && data['recipe'] != null) {
    return Map<String, dynamic>.from(data['recipe']);
  }
  return null;
}
