import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
// import '../../../../core/widgets/glass_container.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/nano_toast.dart';
import '../../../../core/services/offline_manager.dart';
import 'package:chefmind_ai/core/services/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'edit_profile_screen.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../onboarding/presentation/entry_orchestrator.dart';
import '../../auth/presentation/dietary_preferences_screen.dart';
import 'chef_labs_screen.dart';
import 'household_screen.dart';
import '../../guide/presentation/master_guide_screen.dart';
import '../../subscription/presentation/subscription_details_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = false; // Start false, verify in init
  bool _biometricEnabled = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkNotificationPermission();
  }

  Future<void> _loadPreferences() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      final accounts = await ref
          .read(authControllerProvider.notifier)
          .getBiometricAccounts();
      final isEnrolled = accounts.any((acc) => acc['userId'] == user.id);
      if (mounted) {
        setState(() {
          _biometricEnabled = isEnrolled;
        });
      }
    }
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    }
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
                if (mounted) {
                  NanoToast.showSuccess(context, "Biometric Login Enabled");
                }
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
            _buildDetailRow(
                AppLocalizations.of(context)!.settingsUserDetailsUsername,
                username),
            const Divider(color: Colors.white10),
            _buildDetailRow(
                AppLocalizations.of(context)!.settingsUserDetailsEmail, email),
            const Divider(color: Colors.white10),
            Consumer(builder: (context, ref, _) {
              final tierAsync = ref.watch(subscriptionControllerProvider);
              final planName = tierAsync.when(
                data: (tier) {
                  switch (tier) {
                    case SubscriptionTier.sousChef:
                      return AppLocalizations.of(context)!.tierSousChef;
                    case SubscriptionTier.executiveChef:
                      return AppLocalizations.of(context)!.tierExecutiveChef;
                    case SubscriptionTier.homeCook:
                    default:
                      return AppLocalizations.of(context)!.tierHomeCook;
                  }
                },
                loading: () => AppLocalizations.of(context)!.generalLoading,
                error: (_, __) => AppLocalizations.of(context)!.tierFree,
              );
              return _buildDetailRow(
                  AppLocalizations.of(context)!.settingsUserDetailsPlan,
                  planName);
            }),
            const Divider(color: Colors.white10),
            _buildDetailRow(
                AppLocalizations.of(context)!.settingsUserDetailsMemberId,
                memberId),
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
                          Text(AppLocalizations.of(context)!.settingsProfile,
                              style: const TextStyle(
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
                                    builder: (_) => const EntryOrchestrator(
                                          isLogin: false,
                                          skipSplash: true,
                                        )));
                          } else {
                            final isConnected =
                                ref.read(offlineManagerProvider).hasConnection;
                            if (!isConnected) {
                              NanoToast.showInfo(context,
                                  "No connection. Please check your internet.");
                              return;
                            }
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
                                    builder: (_) => const EntryOrchestrator(
                                          isLogin: false,
                                          skipSplash: true,
                                        )))
                            : _showUserDetails(user),
                        child: Text(
                          isGuest
                              ? AppLocalizations.of(context)!
                                  .settingsSignupToSave
                              : AppLocalizations.of(context)!
                                  .settingsShowDetails,
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
                  final authState = ref.watch(authStateChangesProvider);
                  final user = authState.asData?.value.session?.user;
                  final isGuest = user?.isAnonymous ?? true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context)!.settingsSecurity,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Notifications (Simulated "Change PIN" style)
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title:
                            AppLocalizations.of(context)!.settingsNotifications,
                        trailing: Switch(
                          value: _notificationsEnabled,
                          activeColor: AppColors.zestyLime,
                          activeTrackColor:
                              AppColors.zestyLime.withOpacity(0.2),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white10,
                          onChanged: (val) async {
                            if (val) {
                              // Request Permission
                              final status =
                                  await Permission.notification.request();
                              if (status.isGranted) {
                                setState(() => _notificationsEnabled = true);
                                if (context.mounted) {
                                  NanoToast.showSuccess(
                                      context, "Notifications Enabled");
                                }
                              } else if (status.isPermanentlyDenied) {
                                if (context.mounted) {
                                  NanoToast.showError(context,
                                      "Permission denied. Enable in Settings.");
                                  openAppSettings();
                                }
                              } else {
                                if (context.mounted) {
                                  NanoToast.showInfo(context,
                                      "Notifications permission required.");
                                }
                              }
                            } else {
                              setState(() => _notificationsEnabled = false);
                              NanoToast.showInfo(
                                  context, "Notifications Disabled");
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Biometrics (Only for Logged In Users)
                      if (!isGuest)
                        _SettingsTile(
                          icon: Icons.fingerprint,
                          title:
                              AppLocalizations.of(context)!.settingsBiometrics,
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
                      Text(
                        AppLocalizations.of(context)!.settingsSubscription,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Subscription & Billing
                      _SettingsTile(
                        icon: Icons.credit_card,
                        title: AppLocalizations.of(context)!
                            .settingsSubscriptionBilling,
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white54, size: 16),
                        onTap: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubscriptionDetailsScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)!.settingsAccount,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Personalize AI (Visible to ALL)
                      Consumer(builder: (context, ref, _) {
                        final subState =
                            ref.watch(subscriptionControllerProvider);
                        final tier =
                            subState.valueOrNull ?? SubscriptionTier.homeCook;
                        final isPremium = tier != SubscriptionTier.homeCook;

                        return _SettingsTile(
                          icon: Icons.auto_awesome,
                          title: AppLocalizations.of(context)!
                              .settingsPersonalizeAI,
                          subtitle: _buildDietarySummary(user, isPremium),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white54, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DietaryPreferencesScreen(),
                              ),
                            ).then((_) => setState(() {
                                  // Refresh to show updates
                                }));
                          },
                        );
                      }),

                      const SizedBox(height: 8),

                      if (!isGuest) ...[
                        _SettingsTile(
                          icon: Icons.people_outline,
                          title:
                              AppLocalizations.of(context)!.settingsHousehold,
                          trailing: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white54, size: 16),
                          onTap: () {
                            final isConnected =
                                ref.read(offlineManagerProvider).hasConnection;
                            if (!isConnected) {
                              NanoToast.showInfo(context,
                                  "No connection. Please check your internet.");
                              return;
                            }
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HouseholdScreen()));
                          },
                        ),
                        const SizedBox(height: 8),

                        // ChefLabs (Executive Only)
                        Consumer(builder: (context, ref, _) {
                          final subState =
                              ref.watch(subscriptionControllerProvider);
                          final tier =
                              subState.valueOrNull ?? SubscriptionTier.homeCook;
                          if (tier == SubscriptionTier.executiveChef) {
                            return Column(
                              children: [
                                _SettingsTile(
                                  icon: Icons.science,
                                  title: AppLocalizations.of(context)!
                                      .settingsChefLabs,
                                  subtitle: Text(
                                    AppLocalizations.of(context)!
                                        .settingsExperimentalFeatures,
                                    style: const TextStyle(
                                        color: AppColors.zestyLime,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic),
                                  ),
                                  iconColor: AppColors.zestyLime,
                                  trailing: const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white54, size: 16),
                                  onTap: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ChefLabsScreen()));
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        const SizedBox(height: 15),
                      ],

                      // Help & Support
                      Text(
                        AppLocalizations.of(context)!.settingsHelpSupport,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Language Selector
                      Consumer(builder: (context, ref, _) {
                        final currentLocale = ref.watch(localeProvider);
                        final displayLang = currentLocale != null
                            ? '${LocaleNotifier.getFlag(currentLocale.languageCode)} ${LocaleNotifier.getDisplayName(currentLocale.languageCode)}'
                            : '🌐 System Default';

                        return _SettingsTile(
                          icon: Icons.language,
                          title: AppLocalizations.of(context)!.settingsLanguage,
                          subtitle: Text(
                            displayLang,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white54, size: 16),
                          onTap: () => _showLanguagePicker(context, ref),
                        );
                      }),
                      const SizedBox(height: 8),
                      _SettingsTile(
                        icon: Icons.menu_book_rounded,
                        title: AppLocalizations.of(context)!
                            .settingsInstructionManual,
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white54, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MasterGuideScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Sign Out / Log In
                      _SettingsTile(
                        icon: isGuest ? Icons.login : Icons.logout,
                        title: isGuest
                            ? AppLocalizations.of(context)!.authLogin
                            : AppLocalizations.of(context)!.settingsLogout,
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
                                    builder: (_) => const EntryOrchestrator(
                                          isLogin: true,
                                          skipSplash: true,
                                        )));
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

  Widget? _buildDietarySummary(User? user, bool isPremium) {
    // Premium Badge Widget
    final premiumBadge = Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.zestyLime.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.zestyLime.withOpacity(0.5)),
      ),
      child: Text(
        AppLocalizations.of(context)!.settingsSousChefPlus,
        style: const TextStyle(
            color: AppColors.zestyLime,
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );

    if (user == null) {
      // Just show badge if not logged in (should require login anyway but safe fallback)
      return !isPremium ? premiumBadge : null;
    }

    final metadata = user.userMetadata;
    List<String> items = [];

    if (metadata != null && metadata.containsKey('dietary_preferences')) {
      final prefs = metadata['dietary_preferences'];
      if (prefs is List && prefs.isNotEmpty) {
        items = prefs.map((e) => e.toString()).toList();
      }
    }

    if (items.isEmpty) {
      return !isPremium ? premiumBadge : null;
    }

    String text;
    if (items.length <= 2) {
      text = items.join(", ");
    } else {
      text = "${items.take(2).join(', ')} +${items.length - 2} more";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        if (!isPremium) ...[
          const SizedBox(height: 4),
          premiumBadge,
        ]
      ],
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);

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
            Text(
              AppLocalizations.of(context)!.languageSelectTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: LocaleNotifier.supportedLocales.map((locale) {
                    final isSelected =
                        currentLocale?.languageCode == locale.languageCode;
                    return ListTile(
                      leading: Text(
                        LocaleNotifier.getFlag(locale.languageCode),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        LocaleNotifier.getDisplayName(locale.languageCode),
                        style: TextStyle(
                          color:
                              isSelected ? AppColors.zestyLime : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppColors.zestyLime)
                          : null,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(locale);
                        Navigator.pop(context);
                        NanoToast.showSuccess(
                          this.context,
                          "Language changed to ${LocaleNotifier.getDisplayName(locale.languageCode)}",
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
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
  final Widget? subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.subtitle,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor ?? Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      subtitle!,
                    ]
                  ],
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
