import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LiquidMeshBackground extends StatelessWidget {
  const LiquidMeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Layer: Deep Obsidian
        Container(color: const Color(0xFF0A0F0A)),

        // 1. Zesty Lime Blob (Top Right) -> Moving
        const Positioned(
          top: -100,
          right: -50,
          child: _AnimatedBlob(
            color: Color(0xFFD1FF26), // Zesty Lime
            width: 400,
            height: 400,
          ),
        ),

        // 2. Emerald Blob (Bottom Left) -> Moving slower
        const Positioned(
          bottom: 100,
          left: -100,
          child: _AnimatedBlob(
            color: Color(0xFF2D5A27),
            width: 500,
            height: 500,
            delay: Duration(seconds: 2),
            offset: Offset(40, -40),
          ),
        ),

        // 3. Deep Forest Accent (Center Left) -> Pulse
        const Positioned(
          top: 300,
          left: 50,
          child: _AnimatedBlob(
            color: Color(0xFF1A331A),
            width: 300,
            height: 300,
            delay: Duration(seconds: 1),
            offset: Offset(20, 20),
          ),
        ),

        // 4. Mesh Blur Overlay (The "Liquid" Effect)
        // High sigma blur fuses the blobs together
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),

        // 5. Drifting Glass Orbs (Foreground Depth)
        const _DriftingOrb(
          startTop: 150,
          startRight: 40,
          size: 80,
          duration: Duration(seconds: 6),
          yOffset: 30,
        ),
        const _DriftingOrb(
          startTop: 500,
          startRight: 300,
          size: 60,
          duration: Duration(seconds: 8),
          yOffset: -40,
        ),
        const _DriftingOrb(
          startTop: 100,
          startRight: 300,
          size: 40,
          duration: Duration(seconds: 5),
          yOffset: 20,
        ),
      ],
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final Duration delay;
  final Offset offset;

  const _AnimatedBlob({
    required this.color,
    required this.width,
    required this.height,
    this.delay = Duration.zero,
    this.offset = const Offset(30, -30),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.2, 1.2),
            duration: 6.seconds, // Slower for liquid feel
            delay: delay,
            curve: Curves.easeInOut)
        .move(
            begin: const Offset(0, 0),
            end: offset,
            duration: 6.seconds,
            delay: delay,
            curve: Curves.easeInOut);
  }
}

class _DriftingOrb extends StatelessWidget {
  final double startTop;
  final double startRight;
  final double size;
  final Duration duration;
  final double yOffset;

  const _DriftingOrb({
    required this.startTop,
    required this.startRight,
    required this.size,
    required this.duration,
    required this.yOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: startTop,
      right: startRight,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.02)
              ]),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Localized blur
          child: Container(color: Colors.transparent),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
          begin: 0, end: yOffset, duration: duration, curve: Curves.easeInOut),
    );
  }
}
