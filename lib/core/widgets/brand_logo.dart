import 'package:flutter/material.dart';

class BrandLogo extends StatefulWidget {
  final double fontSize;
  final bool isBusy;
  final bool withGlow;

  const BrandLogo({
    super.key,
    this.fontSize = 24.0,
    this.isBusy = false,
    this.withGlow = true,
  });

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.isBusy) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(BrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy != oldWidget.isBusy) {
      if (widget.isBusy) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Shared text style for shadow/glow support
    final Color zestyLime = const Color(0xFFD1FF26);

    // We build the text widget carefully.
    Widget buildText({Color? color, List<Shadow>? shadows}) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'ChefMind',
              style: TextStyle(
                fontFamily: 'Inter', // Fallback to default if not ready
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900, // Heavy Bold
                color: color ?? Colors.white,
                letterSpacing: -0.5,
                shadows: shadows,
              ),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Apply Pulse to AI part only
                  final scale = widget.isBusy ? _pulseAnimation.value : 1.0;
                  // Zesty glow intensifies when busy
                  final currentShadows = widget.isBusy || widget.withGlow
                      ? [
                          Shadow(
                            color: zestyLime
                                .withOpacity(widget.isBusy ? 0.8 : 0.5),
                            blurRadius: widget.isBusy ? 15 : 10,
                            offset: Offset.zero,
                          )
                        ]
                      : null;

                  return Transform.scale(
                    scale: scale,
                    child: Text(
                      'AI',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: widget.fontSize,
                        // ExtraLight is w200 usually
                        fontWeight: FontWeight.w200,
                        color:
                            color ?? (widget.isBusy ? zestyLime : Colors.white),
                        shadows: currentShadows,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Base Layer
    Widget result = buildText(
      shadows: widget.withGlow
          ? [
              Shadow(
                color: zestyLime.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 0),
              )
            ]
          : null,
    );

    // Shimmer Overlay
    if (widget.isBusy) {
      result = AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: const Alignment(-1.0, -0.3),
                end: const Alignment(1.0, 0.3),
                tileMode: TileMode.clamp,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  Colors.white,
                  zestyLime, // Shine color
                  Colors.white,
                ],
                transform: GradientRotation(0.2), // Slight angle
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: result,
      );
    }

    return result;
  }
}
