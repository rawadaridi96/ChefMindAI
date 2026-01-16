import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:chefmind_ai/core/widgets/payment_feedback_modal.dart';
import 'package:flutter/material.dart';

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
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
