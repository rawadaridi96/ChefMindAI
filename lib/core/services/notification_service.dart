import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';

class NotificationService {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void showSuccess(BuildContext context, String message,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    _show(context, message, Icons.check_circle, AppColors.zestyLime,
        onAction: onAction, actionLabel: actionLabel, overlay: overlay);
  }

  static void showError(BuildContext context, String message,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    _show(context, message, Icons.error_outline, AppColors.errorRed,
        onAction: onAction, actionLabel: actionLabel, overlay: overlay);
  }

  static void showInfo(BuildContext context, String message,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    _show(context, message, Icons.info_outline, Colors.white,
        onAction: onAction, actionLabel: actionLabel, overlay: overlay);
  }

  static void _show(
      BuildContext context, String message, IconData icon, Color accentColor,
      {VoidCallback? onAction, String? actionLabel, OverlayState? overlay}) {
    // Dismiss existing toast if any
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
      _timer?.cancel();
    }

    final overlayState = overlay ?? Overlay.of(context);

    // Safety check if overlay is still null
    if (overlayState == null) {
      debugPrint("NotificationService Error: Could not find OverlayState.");
      return;
    }

    _currentEntry = OverlayEntry(
      builder: (context) => _ToastAnimator(
        child: _ToastCapsule(
          message: message,
          icon: icon,
          accentColor: accentColor,
          onAction: onAction,
          actionLabel: actionLabel,
        ),
        onDismissed: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    // Auto dismiss after 3 seconds (can be adjustable)
    _timer = Timer(const Duration(seconds: 3), () {
      // The animator handles the exit animation via a key or we can just let it stay
      // but usually we want to trigger the exit animation.
      // However, with OverlayEntry, triggering exit animation from outside is tricky without a GlobalKey
      // or a stream.
      // For simplicity in this specialized implementation, _ToastAnimator handles its own timing
      // or we can just remove it.
      // Better approach: _ToastAnimator starts a timer to reverse animation.
    });
  }
}

class _ToastAnimator extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;

  const _ToastAnimator({required this.child, required this.onDismissed});

  @override
  State<_ToastAnimator> createState() => _ToastAnimatorState();
}

class _ToastAnimatorState extends State<_ToastAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
    );

    // Spring physics for "Liquid Drop"
    // Drops from -1.0 (above screen) to 0.0 (final pos) with a bounce
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // Springy entrance
      reverseCurve: Curves.easeInBack, // Slide back up
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _controller.forward();

    // Auto-dismiss logic inside the animator
    _timer = Timer(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 20px from top + SafeArea
    final topPadding = MediaQuery.of(context).padding.top + 20;

    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.85, // 85% width
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.up,
                  onDismissed: (_) => widget.onDismissed(),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCapsule extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _ToastCapsule({
    required this.message,
    required this.icon,
    required this.accentColor,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50), // Stadium border
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glassmorphism
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.deepCharcoal
                .withOpacity(0.85), // Semi-transparent dark glass
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular High-Contrast Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 16),

              // Two-tone Typography
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600, // Bold primary
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (onAction != null && actionLabel != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
