import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/liquid_mesh_background.dart';
import 'package:chefmind_ai/core/widgets/brand_logo.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_controller.dart';

import 'package:chefmind_ai/features/auth/presentation/widgets/auth_sheet.dart';

class EntryOrchestrator extends ConsumerStatefulWidget {
  final bool isLogin;
  final bool skipSplash;
  const EntryOrchestrator({
    super.key,
    this.isLogin = true,
    this.skipSplash = false,
  });

  @override
  ConsumerState<EntryOrchestrator> createState() => _EntryOrchestratorState();
}

class _EntryOrchestratorState extends ConsumerState<EntryOrchestrator> {
  // If we are navigating here specifically for auth (e.g. from guest mode), we might want to skip the wait.
  // But for the cinematic effect, let's keep it but maybe shorter if coming from inside app?
  // For now, consistent 3s is fine, or maybe 1s if mounted immediately.
  bool _isAuthReady = false;

  @override
  void initState() {
    super.initState();
    // Simulate initial loading / splash duration
    // In a real app, this might wait for some initialization logic
    if (widget.skipSplash) {
      _isAuthReady = true;
    } else {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isAuthReady = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for global success message (e.g. "Welcome back!")
    // If it arrives, it means we successfully logged in/signed up.
    // If we were pushed (Navigator.canPop), we should close this screen to reveal the previous one (which will also show the toast).
    ref.listen<AuthMessage?>(postLoginMessageProvider, (previous, next) {
      if (next != null) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    });

    // If we are already authenticated, this Orchestrator is likely skipped by main.dart logic
    // But checking here ensures robustness.
    // REMOVED: Checking authState here breaks "Guest -> Login" flow because Guest has a session.
    // main.dart handles the initial routing. Manual pushes should always show UI.

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      resizeToAvoidBottomInset: false, // Let the sheet handle keyboard
      body: Stack(
        children: [
          // 1. Persistent Background (Never Rebuilds/Cuts)
          const Positioned.fill(child: LiquidMeshBackground()),

          // 2. Auth Sheet (Slides up from bottom)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutQuart,
            top: _isAuthReady
                ? (math.max(screenHeight * 0.12, screenHeight - 740) +
                    70) // Anchor to logo center (LogoTop + 70)
                : screenHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: const AuthSheet(),
          ),

          // 3. The Cinematic Logo (Moves from Center -> Top Center)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 3000),
            curve: Curves.elasticOut,
            // Centered initially (approx 45% down), then moves to top area (approx 53px down)
            top: _isAuthReady
                ? math.max(screenHeight * 0.12, screenHeight - 740)
                : screenHeight * 0.40,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment
                  .topCenter, // Ensure it aligns to center horizontally
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOutQuart,
                // Scale down slightly when at top
                transform: Matrix4.identity()..scale(_isAuthReady ? 0.8 : 1.2),
                transformAlignment: Alignment
                    .center, // Critical for keeping it centered while scaling
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The App Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD1FF26).withOpacity(0.6),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Typographic Logo
                    const BrandLogo(fontSize: 32, withGlow: true),
                  ],
                ),
              ),
            ),
          ),

          // 4. Loading Indicator (Fades out when ready)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isAuthReady ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 1600),
              curve: Curves.fastOutSlowIn,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: CircularProgressIndicator(
                    color: AppColors.zestyLime,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
