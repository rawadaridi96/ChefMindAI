import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Data class representing a single onboarding step
class OnboardingStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final TooltipPosition position;

  /// If true, user must tap the spotlight target to proceed (no "Next" button)
  final bool requiresAction;

  /// Optional callback when user taps the spotlight target (for interactive steps)
  final VoidCallback? onAction;

  /// Label for the action button (e.g., "Tap to continue" instead of "Next")
  final String? actionLabel;

  const OnboardingStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.position = TooltipPosition.bottom,
    this.requiresAction = false,
    this.onAction,
    this.actionLabel,
  });
}

/// Where to position the tooltip relative to the target
enum TooltipPosition { top, bottom, left, right }

/// A full-screen overlay that guides users through the app
class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final Function(bool) onDontShowAgainChanged;
  final bool initialDontShowAgain;

  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
    required this.onDontShowAgainChanged,
    this.initialDontShowAgain = false,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _dontShowAgain = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _dontShowAgain = widget.initialDontShowAgain;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onDontShowAgainChanged(_dontShowAgain);
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onDontShowAgainChanged(_dontShowAgain);
    widget.onSkip();
  }

  Rect? _getTargetRect() {
    final step = widget.steps[_currentStep];
    final renderBox =
        step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final targetRect = _getTargetRect();
    final screenSize = MediaQuery.of(context).size;

    // Retry finding target next frame if currently missing (fixes latent mount issues)
    if (targetRect == null && step.targetKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark overlay with spotlight cutout
            if (targetRect != null)
              CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  padding: 8,
                ),
              )
            else
              Container(
                width: screenSize.width,
                height: screenSize.height,
                color: Colors.black.withOpacity(0.8),
              ),

            // Tooltip bubble (rendered first so it's behind the tap area)
            _buildTooltip(context, step, targetRect, screenSize),

            // Interactive spotlight tap area (for requiresAction steps)
            // Rendered AFTER tooltip so it's on top and can receive taps
            if (targetRect != null && step.requiresAction)
              Positioned(
                left: targetRect.left - 8,
                top: targetRect.top - 8,
                width: targetRect.width + 16,
                height: targetRect.height + 16,
                child: GestureDetector(
                  onTap: () {
                    // Execute the action callback
                    step.onAction?.call();
                    // Advance to next step
                    _nextStep();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.zestyLime.withOpacity(0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    OnboardingStep step,
    Rect? targetRect,
    Size screenSize,
  ) {
    // Calculate tooltip position with sufficient gap to not block target
    double top = 0;
    double? left;
    double? right;

    // Estimated tooltip height (for better positioning)
    const tooltipHeight = 200.0; // Compact tooltip
    const gap =
        60.0; // Increased gap to perfectly place tooltip without masking target

    if (targetRect != null) {
      switch (step.position) {
        case TooltipPosition.bottom:
          // Position tooltip below the target with gap
          top = targetRect.bottom + gap;
          left = 20;
          right = 20;

          // If tooltip would go off screen bottom, position it above instead
          if (top + tooltipHeight > screenSize.height - 40) {
            top = targetRect.top - tooltipHeight - gap;
          }
          break;
        case TooltipPosition.top:
          // Position tooltip above the target with gap
          top = targetRect.top - tooltipHeight - gap;
          left = 20;
          right = 20;

          // If tooltip would go off screen top, position it below instead
          if (top < 50) {
            top = targetRect.bottom + gap;
          }
          break;
        case TooltipPosition.left:
          top = targetRect.top;
          right = screenSize.width - targetRect.left + gap;
          break;
        case TooltipPosition.right:
          top = targetRect.top;
          left = targetRect.right + gap;
          break;
      }
    } else {
      // Center the tooltip if no target
      top = screenSize.height / 2 - 100;
      left = 20;
      right = 20;
    }

    // Final bounds check to keep tooltip on screen
    if (top < 50) top = 50;
    if (top > screenSize.height - tooltipHeight - 40) {
      top = screenSize.height - tooltipHeight - 40;
    }

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(_currentStep),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.deepCharcoal,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.zestyLime.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.zestyLime.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.zestyLime.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentStep + 1} / ${widget.steps.length}',
                      style: const TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Skip button
                  if (_currentStep < widget.steps.length - 1)
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                step.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                step.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // Don't show again checkbox + Navigation buttons (same row)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Checkbox
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _dontShowAgain,
                          onChanged: (val) =>
                              setState(() => _dontShowAgain = val ?? false),
                          activeColor: AppColors.zestyLime,
                          checkColor: AppColors.deepCharcoal,
                          side: BorderSide(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Don't show again",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Next / Done button (or action hint for interactive steps)
                  if (step.requiresAction)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.zestyLime.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.zestyLime.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            color: AppColors.zestyLime,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            step.actionLabel ?? 'Tap to continue',
                            style: TextStyle(
                              color: AppColors.zestyLime,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _currentStep < widget.steps.length - 1
                            ? 'Next'
                            : 'Done',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

/// Painter that creates a spotlight effect on the target widget
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double padding;

  _SpotlightPainter({
    required this.targetRect,
    this.padding = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Create a path that covers the whole screen
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create the spotlight cutout with rounded corners
    final spotlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        targetRect.left - padding,
        targetRect.top - padding,
        targetRect.width + padding * 2,
        targetRect.height + padding * 2,
      ),
      const Radius.circular(12),
    );
    final spotlightPath = Path()..addRRect(spotlightRect);

    // Subtract the spotlight from the full path
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      spotlightPath,
    );

    canvas.drawPath(overlayPath, paint);

    // Add a subtle glow around the spotlight
    final glowPaint = Paint()
      ..color = AppColors.zestyLime.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(spotlightRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
