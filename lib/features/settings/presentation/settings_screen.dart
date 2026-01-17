import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
// import '../../../../core/widgets/glass_container.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chefmind_ai/core/services/payment_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/nano_toast.dart';
import 'edit_profile_screen.dart';
import '../../auth/presentation/dietary_preferences_screen.dart';
import '../../auth/presentation/auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      // Enabling Biometrics
      final bool canCheck = await auth.canCheckBiometrics;
      final bool isSupported = await auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        if (mounted) {
          NanoToast.showError(
              context, "Biometrics not supported on this device");
        }
        return;
      }

      // Verify Biometrics First
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (!didAuthenticate) return;
      } catch (e) {
        if (mounted) NanoToast.showError(context, "Authentication failed");
        return;
      }

      // Ask for current password to store credentials
      if (mounted) _showPasswordConfirmationDialog();
    } else {
      // Disabling Biometrics
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await ref
            .read(authControllerProvider.notifier)
            .removeBiometricAccount(user.id);
        setState(() => _biometricEnabled = false);
        if (mounted) NanoToast.showInfo(context, "Biometric Login Disabled");
      }
    }
  }

  void _showPasswordConfirmationDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title: const Text("Confirm Password",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Please enter your password to securely enable biometric login.",
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Password",
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
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) return;

              Navigator.pop(context); // Close dialog

              // Verify password by re-authenticating (optional but safer)
              // OR just trust it and store it.
              // For UX, let's just store it. If it's wrong, next biometric login will fail at Supabase level (safe enough).

              final user = ref.read(authRepositoryProvider).currentUser;
              if (user != null) {
                await ref
                    .read(authControllerProvider.notifier)
                    .storeBiometricCredentials(
                      user.email!,
                      password,
                      user.id,
                      displayName: user.userMetadata?['full_name'] as String?,
                      avatarUrl: user.userMetadata?['avatar_url'] as String?,
                    );

                setState(() => _biometricEnabled = true);
                if (mounted)
                  NanoToast.showSuccess(context, "Biometric Login Enabled");
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zestyLime,
                foregroundColor: AppColors.deepCharcoal),
            child: const Text("Enable"),
          )
        ],
      ),
    );
  }

  void _showUserDetails(User? user) {
    if (user == null) return;

    final email = user.email ?? 'Unknown';

    // Consistent Name Logic
    String username = email.split('@')[0];
    final metadata = user.userMetadata;

    if (metadata != null && metadata.containsKey('full_name')) {
      username = metadata['full_name'].toString();
    } else if (metadata != null && metadata.containsKey('name')) {
      username = metadata['name'].toString();
    } else {
      username = username.replaceAll(RegExp(r'[._]'), ' ');
      // Capitalize first letters of words
      username = username
          .split(' ')
          .map((str) => str.isNotEmpty
              ? '${str[0].toUpperCase()}${str.substring(1)}'
              : '')
          .join(' ');
    }

    // Create a pseudo-ID from the UUID for display
    final memberId = "CM-${user.id.substring(0, 6).toUpperCase()}";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            _buildDetailRow("Username", username),
            const Divider(color: Colors.white10),
            _buildDetailRow("Email", email),
            const Divider(color: Colors.white10),
            _buildDetailRow(
                "Plan", "Pro Member"), // Placeholder until subscription sync
            const Divider(color: Colors.white10),
            _buildDetailRow("Member ID", memberId),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.zestyLime,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.only(
                  top: 60, bottom: 32, left: 16, right: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2C2C2C),
                    AppColors.deepCharcoal,
                  ],
                ),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final authState = ref.watch(authStateChangesProvider);
                  final user = authState.asData?.value.session?.user;
                  final email = user?.email ?? 'Guest';
                  final isGuest = user?.isAnonymous ?? true;

                  // Priority: Metadata Name -> Formatted Email
                  String username = 'Guest';
                  final metadata = user?.userMetadata;

                  if (!isGuest) {
                    if (metadata != null && metadata.containsKey('full_name')) {
                      username = metadata['full_name'].toString().toUpperCase();
                    } else if (metadata != null &&
                        metadata.containsKey('name')) {
                      username = metadata['name'].toString().toUpperCase();
                    } else {
                      // Fallback: Replace . and _ with spaces
                      final handle = email.split('@')[0];
                      username =
                          handle.replaceAll(RegExp(r'[._]'), ' ').toUpperCase();
                    }
                  } else {
                    username = "GUEST CHEF";
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text("Profile",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 48), // Balance for back button
                        ],
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () {
                          if (isGuest) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AuthScreen(
                                        isLogin: false))); // Go to Sign Up
                          } else {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen()));
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.zestyLime, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white10,
                                backgroundImage: !isGuest &&
                                        user?.userMetadata?['avatar_url'] !=
                                            null
                                    ? NetworkImage(
                                        user!.userMetadata!['avatar_url'])
                                    : null,
                                child: isGuest ||
                                        user?.userMetadata?['avatar_url'] ==
                                            null
                                    ? const Icon(Icons.person_outline,
                                        size: 30, color: Colors.white)
                                    : null,
                              ),
                            ),
                            if (!isGuest)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.zestyLime,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 14, color: AppColors.deepCharcoal),
                                ),
                              )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => isGuest
                            ? Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AuthScreen(isLogin: false)))
                            : _showUserDetails(user),
                        child: Text(
                          isGuest
                              ? "Sign up to save your settings"
                              : "Show details",
                          style: const TextStyle(
                              color: AppColors.zestyLime,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Settings List
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer(
                builder: (context, ref, _) {
                  final user = ref
                      .read(authRepositoryProvider)
                      .currentUser; // Direct read for logic
                  final isGuest = user?.isAnonymous ?? true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "Privacy and Security",
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Notifications (Simulated "Change PIN" style)
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: "Push Notifications",
                        trailing: Switch(
                          value: _notificationsEnabled,
                          activeColor: AppColors.zestyLime,
                          activeTrackColor:
                              AppColors.zestyLime.withOpacity(0.2),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white10,
                          onChanged: (val) {
                            setState(() => _notificationsEnabled = val);
                            NanoToast.showInfo(
                                context,
                                val
                                    ? "Notifications Enabled"
                                    : "Notifications Disabled");
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Biometrics (Only for Logged In Users)
                      if (!isGuest)
                        _SettingsTile(
                          icon: Icons.fingerprint,
                          title: "Biometric Login",
                          trailing: Switch(
                            value: _biometricEnabled,
                            activeColor: AppColors.zestyLime,
                            activeTrackColor:
                                AppColors.zestyLime.withOpacity(0.2),
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.white10,
                            onChanged: _toggleBiometrics,
                          ),
                        ),

                      const SizedBox(height: 24),
                      const Text(
                        "Subscription",
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Subscription & Billing
                      _SettingsTile(
                        icon: Icons.credit_card,
                        title: "Subscription & Billing",
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white54, size: 16),
                        onTap: () async {
                          if (isGuest) {
                            NanoToast.showInfo(
                                context, "Please sign up to subscribe.");
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AuthScreen(isLogin: false)));
                            return;
                          }

                          final url = ref
                              .read(paymentServiceProvider)
                              .getBillingPortalUrl();
                          final uri = Uri.parse(url);
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              // Fallback
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              NanoToast.showError(
                                  context, "Could not open billing portal");
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 24),
                      if (!isGuest) ...[
                        const Text(
                          "Account",
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _SettingsTile(
                          icon: Icons.auto_awesome,
                          title: "Personalize AI Chef",
                          trailing: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white54, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DietaryPreferencesScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Sign Out / Log In
                      _SettingsTile(
                        icon: isGuest ? Icons.login : Icons.logout,
                        title: isGuest ? "Log In / Sign Up" : "Sign Out",
                        iconColor:
                            isGuest ? AppColors.zestyLime : AppColors.errorRed,
                        textColor: isGuest ? Colors.white : AppColors.errorRed,
                        trailing: Icon(Icons.arrow_forward_ios,
                            color:
                                isGuest ? Colors.white54 : AppColors.errorRed,
                            size: 16),
                        onTap: () {
                          if (isGuest) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AuthScreen(isLogin: true)));
                          } else {
                            ref.read(authControllerProvider.notifier).signOut();
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.zestyLime).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.zestyLime,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
