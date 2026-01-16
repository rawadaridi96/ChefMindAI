import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:chefmind_ai/core/utils/validators.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'widgets/biometric_enrollment_modal.dart';
import '../data/auth_repository.dart';

import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _isLogin = true;
  bool _isPasswordVisible = false;
  bool _rememberMe = true;
  List<Map<String, dynamic>> _biometricAccounts = [];

  // Hybrid Adaptive State
  Map<String, dynamic>? _selectedBiometricAccount;
  bool _showPasswordField = false;
  int _biometricAttempts = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });

    _loadUserPreferences();
    _loadBiometricAccounts();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? true;
      if (_rememberMe) {
        _emailController.text = prefs.getString('saved_email') ?? '';
      }
    });
  }

  Future<void> _loadBiometricAccounts() async {
    final accounts =
        await ref.read(authControllerProvider.notifier).getBiometricAccounts();
    setState(() {
      _biometricAccounts = accounts;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onAccountSelected(Map<String, dynamic> account) {
    setState(() {
      _selectedBiometricAccount = account;
      _isLogin = true;
      _emailController.text = account['email'] ?? '';
      _showPasswordField = false;
      _biometricAttempts = 0;
      _formKey.currentState?.reset(); // Clear errors
    });
  }

  void _switchAccount() {
    setState(() {
      _selectedBiometricAccount = null;
      _emailController.clear();
      _passwordController.clear();
      _showPasswordField = false;
      _biometricAttempts = 0;
    });
  }

  Future<void> _triggerBiometricAuth() async {
    if (_selectedBiometricAccount == null) return;

    try {
      await ref
          .read(authControllerProvider.notifier)
          .authenticateWithBiometrics(_selectedBiometricAccount!['userId']);
      // Success is handled in the listener
    } catch (e) {
      setState(() {
        _biometricAttempts++;
      });
      if (_biometricAttempts >= 3) {
        _shakeController.forward();
        setState(() {
          _showPasswordField = true;
        });
        NanoToast.showError(
            context, "Too many failed attempts. Please use password.");
      } else {
        NanoToast.showError(context, "Biometric verification failed");
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (_isLogin) {
      ref.read(authControllerProvider.notifier).signIn(
            email,
            password,
            rememberMe: _rememberMe,
          );
    } else {
      ref.read(authControllerProvider.notifier).signUp(
            email,
            password,
            fullName: name,
            rememberMe: _rememberMe,
          );
    }
  }

  void _forgotPassword() {
    // ... existing logic ...
    final resetEmailController =
        TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title:
            const Text("Reset Password", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email to receive a recovery link.",
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.zestyLime)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final email = resetEmailController.text.trim();
              if (Validators.validateEmail(email) != null) {
                NanoToast.showError(context, "Invalid email address");
                return;
              }
              ref.read(authControllerProvider.notifier).resetPassword(email);
              Navigator.pop(context);
              NanoToast.showInfo(context, "Recovery link sent to $email");
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zestyLime,
                foregroundColor: AppColors.deepCharcoal),
            child: const Text("Send Link"),
          )
        ],
      ),
    );
  }

  void _checkAndTriggerEnrollment() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await _loadBiometricAccounts();
      final isEnrolled =
          _biometricAccounts.any((acc) => acc['userId'] == user.id);

      if (!isEnrolled) {
        showDialog(
          context: context,
          builder: (context) => BiometricEnrollmentModal(
            email: user.email ?? 'your account',
            onEnable: () async {
              Navigator.pop(context);
              final password = _passwordController.text;
              if (password.isNotEmpty) {
                await ref
                    .read(authControllerProvider.notifier)
                    .storeBiometricCredentials(
                      user.email!,
                      password,
                      user.id,
                      displayName: user.userMetadata?['full_name'] as String?,
                      avatarUrl: user.userMetadata?['avatar_url'] as String?,
                    );
                if (mounted) {
                  NanoToast.showSuccess(
                      context, "Biometrics enabled for ${user.email}");
                }
                _loadBiometricAccounts();
              }
            },
            onSkip: () => Navigator.pop(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final user = ref.read(authRepositoryProvider).currentUser;
    final displayName =
        user?.userMetadata?['full_name'] ?? _emailController.text;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        NanoToast.showError(context, next.error.toString());
        // If error on biometric auth, user might need to use password.
        // But invalid password on biometric might be different.
      } else if (next.hasValue &&
          !next.isLoading &&
          (previous?.isLoading ?? false)) {
        if (_isLogin) {
          NanoToast.showSuccess(context, "Welcome back, $displayName!");
          _checkAndTriggerEnrollment();
        } else {
          NanoToast.showSuccess(
              context, "Account created! Please check your email.");
          _checkAndTriggerEnrollment();
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                              _shakeAnimation.value *
                                  (1 -
                                      2 * (_shakeController.value - 0.5).abs()),
                              0),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          const Icon(Icons.restaurant_menu,
                              size: 60, color: AppColors.zestyLime),
                          const SizedBox(height: 16),
                          Text(
                            'CHEFMIND AI',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 48),

                          // Account Picker
                          if (_biometricAccounts.isNotEmpty) ...[
                            _buildAccountPicker(),
                            const SizedBox(height: 24),
                          ],

                          GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                        scale: animation, child: child));
                              },
                              child: _selectedBiometricAccount != null
                                  ? _buildBiometricView(state.isLoading)
                                  : _buildFullForm(state.isLoading),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Only show "Already have account?" text if full form is active
                          if (_selectedBiometricAccount == null)
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
                                      text: _isLogin ? 'Sign Up' : 'Sign In',
                                      style: const TextStyle(
                                          color: AppColors.zestyLime,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountPicker() {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _biometricAccounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final account = _biometricAccounts[index];
          final email = account['email'] ?? 'Unknown';
          final displayName = account['displayName'];
          final avatarUrl = account['avatarUrl'];

          final isSelected = _selectedBiometricAccount != null &&
              _selectedBiometricAccount!['userId'] == account['userId'];

          String initials = "U";
          if (displayName != null && displayName.isNotEmpty) {
            initials = displayName[0].toUpperCase();
          } else if (email.isNotEmpty) {
            initials = email[0].toUpperCase();
          }

          return GestureDetector(
            onTap: () => _onAccountSelected(account),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: isSelected
                              ? AppColors.zestyLime
                              : Colors.transparent,
                          width: 2),
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: AppColors.zestyLime.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 0))
                            ]
                          : []),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white10,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayName ?? email.split('@')[0],
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, VoidCallback onTap) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricView(bool isLoading) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.zestyLime)),
      );
    }
    return Column(
      key: const ValueKey('BiometricView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome back,',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedBiometricAccount?['displayName'] ??
              _selectedBiometricAccount?['email']?.split('@')[0] ??
              'User',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),

        // Neumorphic Biometric Button - BIG
        Center(
          child: GestureDetector(
            onTap: _triggerBiometricAuth,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                  color: AppColors.zestyLime,
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.zestyLime,
                      Color.lerp(AppColors.zestyLime, Colors.black, 0.2)!
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.zestyLime.withOpacity(0.4),
                        offset: const Offset(4, 4),
                        blurRadius: 10,
                        spreadRadius: 1),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        offset: const Offset(-4, -4),
                        blurRadius: 10,
                        spreadRadius: 1),
                  ]),
              child: const Icon(Icons.fingerprint,
                  size: 64, color: AppColors.deepCharcoal),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Tap to Sign In",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.zestyLime,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),

        const SizedBox(height: 32),

        if (_showPasswordField) ...[
          TextFormField(
            controller: _passwordController,
            autofillHints: const [AutofillHints.password],
            validator: (val) =>
                val != null && val.isNotEmpty ? null : 'Password is required',
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.zestyLime,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.white38),
              floatingLabelStyle: const TextStyle(color: AppColors.zestyLime),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.zestyLime)),
              filled: true,
              fillColor: Colors.black12,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Normal sign in with pre-filled email
              _submit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.zestyLime,
              foregroundColor: AppColors.deepCharcoal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (!_showPasswordField)
          TextButton(
            onPressed: () {
              setState(() => _showPasswordField = true);
            },
            child: const Text("Use Password instead",
                style: TextStyle(color: Colors.white54)),
          ),

        const Divider(color: Colors.white10),

        TextButton(
          onPressed: _switchAccount,
          child: const Text("Not you? Switch Account",
              style: TextStyle(color: AppColors.zestyLime)),
        ),
      ],
    );
  }

  // Refactored Full Form into its own method for cleaner build
  Widget _buildFullForm(bool isLoading) {
    if (isLoading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.zestyLime));

    return Column(
        key: const ValueKey('FullForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isLogin ? 'Welcome Back' : 'Create Account',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin
                ? 'Enter your details to access your kitchen.'
                : 'Join the revolution of AI cooking.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (!_isLogin) ...[
            TextFormField(
              controller: _nameController,
              validator: (val) => val != null && val.isNotEmpty
                  ? null
                  : 'Full Name is required',
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              cursorColor: AppColors.zestyLime,
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(color: Colors.white38),
                floatingLabelStyle: const TextStyle(color: AppColors.zestyLime),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.zestyLime)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.errorRed)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.errorRed)),
                filled: true,
                fillColor: Colors.black12,
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            validator: Validators.validateEmail,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.zestyLime,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Colors.white38),
              floatingLabelStyle: const TextStyle(color: AppColors.zestyLime),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.zestyLime)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.errorRed)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.errorRed)),
              filled: true,
              fillColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            autofillHints: const [AutofillHints.password],
            // Only validate complexity on Sign Up, not Login
            validator: (val) => _isLogin
                ? (val != null && val.isNotEmpty
                    ? null
                    : 'Password is required')
                : Validators.validatePassword(val),
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.zestyLime,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.white38),
              floatingLabelStyle: const TextStyle(color: AppColors.zestyLime),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.zestyLime)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.errorRed)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.errorRed)),
              filled: true,
              fillColor: Colors.black12,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          if (_isLogin) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) =>
                            setState(() => _rememberMe = val ?? true),
                        activeColor: AppColors.zestyLime,
                        checkColor: AppColors.deepCharcoal,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                    const Text("Remember Me",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                TextButton(
                  onPressed: _forgotPassword,
                  child: const Text("Forgot Password?",
                      style:
                          TextStyle(color: AppColors.zestyLime, fontSize: 13)),
                )
              ],
            )
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.zestyLime,
              foregroundColor: AppColors.deepCharcoal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              _isLogin ? 'Sign In' : 'Sign Up',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: Divider(color: Colors.white10)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("OR",
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSocialButton(
                    Icons.apple,
                    "Apple",
                    () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithApple()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSocialButton(
                    Icons.g_mobiledata,
                    "Google",
                    () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle()),
              ),
            ],
          ),
        ]);
  }
}
