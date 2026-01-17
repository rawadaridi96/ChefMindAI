import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/liquid_mesh_background.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_state_provider.dart';
import 'package:chefmind_ai/features/auth/presentation/widgets/auth_sheet.dart';

class EntryOrchestrator extends ConsumerStatefulWidget {
  const EntryOrchestrator({super.key});

  @override
  ConsumerState<EntryOrchestrator> createState() => _EntryOrchestratorState();
}

class _EntryOrchestratorState extends ConsumerState<EntryOrchestrator> {
  bool _isAuthReady = false;

  @override
  void initState() {
    super.initState();
    // Simulate initial loading / splash duration
    // In a real app, this might wait for some initialization logic
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isAuthReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If we are already authenticated, this Orchestrator is likely skipped by main.dart logic
    // But checking here ensures robustness.
    final authState = ref.watch(authStateChangesProvider);

    // Safety check: if logged in, do nothing (Main handles nav), or show empty to prevent flash
    if (authState.asData?.value.session != null) {
      return const SizedBox();
    }

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
                ? 120
                : screenHeight, // Starts at 120 to intersect Logo
            left: 0,
            right: 0,
            bottom: 0,
            child: const AuthSheet(),
          ),

          // 3. The Cinematic Logo (Moves from Center -> Top Center)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 4000),
            curve: Curves.elasticOut,
            // Centered initially (approx 45% down), then moves to top area (approx 53px down)
            top: _isAuthReady ? 53 : screenHeight * 0.40,
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
                    // Logo Image
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(
                            color: AppColors.zestyLime
                                .withOpacity(_isAuthReady ? 0.2 : 0.5),
                            blurRadius: _isAuthReady ? 20 : 50,
                            spreadRadius: _isAuthReady ? 2 : 10,
                          )
                        ]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Image.asset(
                            'assets/app_icon.jpg',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title Text
                    const Text(
                      'ChefMindAI',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Loading Indicator (Fades out when ready)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isAuthReady ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
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
