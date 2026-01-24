import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/services/notification_service.dart';

class NanoToast {
  static void showSuccess(BuildContext context, String message,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    NotificationService.showSuccess(context, message,
        onAction: onAction, actionLabel: actionLabel, overlay: overlay);
  }

  static void showError(BuildContext context, String message,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    NotificationService.showError(context, message,
        onAction: onAction, actionLabel: actionLabel, overlay: overlay);
  }

  static void showInfo(BuildContext context, String message,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    NotificationService.showInfo(context, message,
        onAction: onAction, actionLabel: actionLabel, overlay: overlay);
  }
}
