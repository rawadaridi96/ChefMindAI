import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_controller.dart';
import 'package:chefmind_ai/features/onboarding/presentation/entry_orchestrator.dart';
import 'package:chefmind_ai/core/widgets/liquid_mesh_background.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  bool _showAuthOptions = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      next.when(
        data: (_) {},
        loading: () {
          // You could show a loading overlay here if desired
        },
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Guest Login Failed: ${error.toString()}'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A), // Deep Obsidian Base
      body: Stack(
        children: [
          // 1. Liquid Mesh Gradient Background
          const LiquidMeshBackground(),

          // 2. Content Layer
          SafeArea(
            child: Stack(
              children: [
                // Floating Logo (Top 1/3)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                alignment: Alignment.center,
                                color: Colors.white.withOpacity(0.05),
                                // Using Icon as Logo for scalability/theme consistency
                                // Using App Icon for consistency
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.asset(
                                    'assets/app_icon.png',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                            .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true))
                            .moveY(
                                begin: 0,
                                end: -15,
                                duration: 3.seconds,
                                curve: Curves.easeInOut),
                        const SizedBox(height: 24),
                        const Text(
                          "ChefMindAI",
                          style: TextStyle(
                            fontFamily: 'Montserrat', // Ensuring stylized font
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 4,
                            color: Colors.white,
                          ),
                        ).animate().fadeIn(duration: 800.ms).moveY(
                            begin: 10,
                            end: 0,
                            duration: 800.ms,
                            curve: Curves.easeOut),
                      ],
                    ),
                  ),
                ),

                // Bottom Sheet (Glassmorphic)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildGlassBottomSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBottomSheet(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dynamic Content Switcher
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                child: _showAuthOptions
                    ? _buildAuthOptions()
                    : _buildWelcomeContent(),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(
        begin: 1.0,
        end: 0,
        duration: 800.ms,
        curve: Curves.easeOutBack,
        delay: 200.ms);
  }

  Widget _buildWelcomeContent() {
    return Column(
      key: const ValueKey('Welcome'),
      children: [
        const Text(
          "Unlock the Kitchen",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Experience the future of culinary creativity with AI-powered recipes and pantry management.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showAuthOptions = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.zestyLime,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Get Started",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthOptions() {
    return Column(
      key: const ValueKey('Auth'),
      children: [
        const Text(
          "How would you like to continue?",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),

        // Primary Actions: Sign Up & Log In
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EntryOrchestrator(
                              isLogin: true,
                              skipSplash: true,
                            )),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Log In",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EntryOrchestrator(
                              isLogin: false,
                              skipSplash: true,
                            )),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.zestyLime,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Socials
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassSocialButton(
              icon: Icons.apple,
              onTap: () {
                ref.read(authControllerProvider.notifier).signInWithApple();
              },
            ),
            const SizedBox(width: 24),
            _GlassSocialButton(
              icon: Icons.g_mobiledata_rounded, // Placeholder for Google G logo
              onTap: () {
                ref.read(authControllerProvider.notifier).signInWithGoogle();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Guest
        TextButton(
          onPressed: () {
            ref.read(authControllerProvider.notifier).signInAnonymously();
          },
          child: const Text(
            "Continue as Guest",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white24,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _GlassSocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassSocialButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
