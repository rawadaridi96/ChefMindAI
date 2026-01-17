import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AuthSheet extends ConsumerStatefulWidget {
  const AuthSheet({super.key});

  @override
  ConsumerState<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<AuthSheet> {
  bool _isLogin = true; // Default to Log In
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        ref.read(authControllerProvider.notifier).signIn(email, password);
      } else {
        final name = _nameController.text.trim();
        ref
            .read(authControllerProvider.notifier)
            .signUp(email, password, fullName: name.isNotEmpty ? name : null);
      }
    }
  }

  Future<void> _triggerBiometric() async {
    try {
      // Check for any stored accounts
      final accounts = await ref
          .read(authControllerProvider.notifier)
          .getBiometricAccounts();
      if (accounts.isNotEmpty) {
        // Use the most recent or first one
        final userId = accounts.first['userId'];
        await ref
            .read(authControllerProvider.notifier)
            .authenticateWithBiometrics(userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No biometric credentials found.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Biometric Auth Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Glassmorphic Sheet
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipPath(
        clipper: const _ValleyClipper(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                24, 100, 24, 40), // Increased spacing between notch and title
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F0A).withOpacity(0.7), // Obsidian Glass
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.1), width: 1)),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Inputs ---
                    if (!_isLogin) ...[
                      _buildGlassTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildGlassTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildGlassTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isPasswordVisible: _isPasswordVisible,
                      onTogglePassword: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),

                    // --- Forgot Password (Log In only) ---
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            if (_emailController.text.isNotEmpty) {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .resetPassword(_emailController.text.trim());
                              // Maybe show toast here?
                            }
                          },
                          child: const Text('Forgot Password?',
                              style: TextStyle(
                                  color: AppColors.zestyLime,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // --- Primary Action & Biometric ---
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.zestyLime,
                              foregroundColor: AppColors.deepCharcoal,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text(
                              _isLogin ? 'Log In' : 'Sign Up',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        if (_isLogin) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              // Start biometric auth
                              // We need a userId - typically biometrics work after first login/setup
                              // or checking if *any* biometrics are stored.
                              // For now, we can try generic auth if stored.
                              // Since we don't have user ID yet... we usually check local storage for 'last_user' or iterate.
                              // This simple implementation might need to be smarter in a real app.
                              // We'll call a method that tries to find ANY enrolled user.
                              // But 'authenticateWithBiometrics' needs a userID.
                              // Let's assume we find the first enrolled user for this demo if not specific.
                              _triggerBiometric();
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.fingerprint,
                                  color: AppColors.zestyLime, size: 28),
                            ),
                          ),
                        ]
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Dividers ---
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white12)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text("or continue with",
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: Colors.white12)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Revolut-style Social Row ---
                    Row(
                      children: [
                        // Google
                        Expanded(
                          child: _SocialButton(
                            icon: FontAwesomeIcons.google,
                            label: 'Google',
                            onTap: () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Apple
                        Expanded(
                          child: _SocialButton(
                            icon: FontAwesomeIcons.apple,
                            label: 'Apple',
                            onTap: () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithApple();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // --- Toggle / Guest ---
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: RichText(
                        text: TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : "Already have an account? ",
                          style: const TextStyle(color: Colors.white54),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Sign Up' : 'Log In',
                              style: const TextStyle(
                                  color: AppColors.zestyLime,
                                  fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        ref
                            .read(authControllerProvider.notifier)
                            .signInAnonymously();
                      },
                      child: const Text('Continue as Guest',
                          style: TextStyle(
                              color: AppColors.zestyLime, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white),
        cursorColor: AppColors.zestyLime,
        validator: (val) {
          if (val == null || val.isEmpty) return '$label is required';
          if (label == 'Email' && !val.contains('@')) return 'Invalid email';
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white38),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white38),
                  onPressed: onTogglePassword,
                )
              : null,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          floatingLabelStyle: const TextStyle(color: AppColors.zestyLime),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ValleyClipper extends CustomClipper<Path> {
  const _ValleyClipper();

  @override
  Path getClip(Size size) {
    final double width = size.width;
    final double height = size.height;
    const double radius = 40.0; // Corner radius
    const double notchRadius = 45.0; // Radius of the notch cut

    final path = Path();

    // Top Left Corner
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    // Line to Notch Start
    path.lineTo((width / 2) - notchRadius - 10, 0);

    // The Notch (Valley) - Smooth transition
    // We curve down into the notch
    path.quadraticBezierTo(
        (width / 2) - notchRadius,
        0, // Control point
        (width / 2) - notchRadius + 5,
        10 // Start of dip
        );

    path.arcToPoint(
      Offset((width / 2) + notchRadius - 5, 10),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    path.quadraticBezierTo(
        (width / 2) + notchRadius, 0, (width / 2) + notchRadius + 10, 0);

    // Line to Top Right
    path.lineTo(width - radius, 0);
    path.quadraticBezierTo(width, 0, width, radius);

    // Bottom Right
    path.lineTo(width, height);

    // Bottom Left
    path.lineTo(0, height);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
