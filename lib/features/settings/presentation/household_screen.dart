import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/nano_toast.dart';
import 'package:chefmind_ai/core/widgets/network_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'household_controller.dart';
import '../data/household_repository.dart';
import '../../subscription/presentation/subscription_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  final _createNameController = TextEditingController();
  final _joinCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Listen for changes in household state to reset inputs
    ref.listen(householdControllerProvider, (previous, next) {
      final prevHouse = previous?.valueOrNull;
      final nextHouse = next.valueOrNull;

      // Logic: Clear inputs whenever we cross the boundary of being in/out of a household
      // 1. Successfully joined/created (Null -> Data)
      if (prevHouse == null && nextHouse != null) {
        _createNameController.clear();
        _joinCodeController.clear();
      }
      // 2. Left/Deleted/Kicked (Data -> Null)
      else if (prevHouse != null && nextHouse == null) {
        _createNameController.clear();
        _joinCodeController.clear();
      }
    });

    final householdState = ref.watch(householdControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.householdTitle,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.zestyLime),
      ),
      body: householdState.when(
        data: (household) {
          if (household == null) {
            return _buildCreateJoinView();
          }
          return _buildDashboardView(household);
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.zestyLime)),
        error: (err, st) {
          if (NetworkErrorView.isNetworkError(err)) {
            return NetworkErrorView(
              onRetry: () => ref.invalidate(householdControllerProvider),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.errorRed, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Something went wrong",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    err.toString().contains("JWT")
                        ? "Your session has expired. Please restart the app or sign out."
                        : "Error: $err",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(householdControllerProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.zestyLime,
                      foregroundColor: AppColors.deepCharcoal,
                    ),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateJoinView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.householdSyncKitchen,
            style: const TextStyle(
                color: AppColors.zestyLime,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.householdSyncDescription,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Create Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.householdCreateNew,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _createNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.householdNameHint,
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Consumer(builder: (context, ref, _) {
                    final subState = ref.watch(subscriptionControllerProvider);
                    final tier =
                        subState.valueOrNull ?? SubscriptionTier.homeCook;
                    final isExecutive = tier == SubscriptionTier.executiveChef;

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExecutive
                            ? AppColors.zestyLime
                            : Colors.white12, // Greyed out if locked
                        foregroundColor: isExecutive
                            ? AppColors.deepCharcoal
                            : Colors.white38, // Dim text
                        disabledBackgroundColor: Colors.white10,
                      ),
                      onPressed: isExecutive
                          ? () async {
                              // Action for Executive Chef
                              if (_createNameController.text.trim().isEmpty) {
                                NanoToast.showError(
                                    context,
                                    AppLocalizations.of(context)!
                                        .householdEnterName);
                                return;
                              }
                              await ref
                                  .read(householdControllerProvider.notifier)
                                  .createHousehold(_createNameController.text);
                            }
                          : () {
                              // Action for non-Executive (Show Toast/Upgrade)
                              NanoToast.showInfo(
                                  context,
                                  AppLocalizations.of(context)!
                                      .householdExecutiveRequired);
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isExecutive) ...[
                            const Icon(Icons.lock,
                                size: 16, color: Colors.white38),
                            const SizedBox(width: 8),
                          ],
                          Text(AppLocalizations.of(context)!.householdCreate),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Row(children: [
            const Expanded(child: Divider(color: Colors.white24)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(AppLocalizations.of(context)!.householdOr,
                    style: const TextStyle(color: Colors.white54))),
            const Expanded(child: Divider(color: Colors.white24))
          ]),
          const SizedBox(height: 24),

          // Join Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.householdJoinExisting,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _joinCodeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.householdEnterCode,
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner,
                          color: AppColors.zestyLime),
                      tooltip: AppLocalizations.of(context)!.householdScanQR,
                      onPressed: () async {
                        final code = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) {
                              bool isScanned = false;
                              return Scaffold(
                                appBar: AppBar(
                                  title: const Text("Scan QR Code"),
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  iconTheme:
                                      const IconThemeData(color: Colors.white),
                                ),
                                backgroundColor: Colors.black,
                                body: Stack(
                                  children: [
                                    MobileScanner(
                                      // Darken outside the scan area
                                      overlayBuilder: (context, constraints) {
                                        final double scanWindowSize = 250;
                                        final double left =
                                            (constraints.maxWidth -
                                                    scanWindowSize) /
                                                2;
                                        final double top =
                                            (constraints.maxHeight -
                                                    scanWindowSize) /
                                                2;

                                        return Stack(
                                          children: [
                                            // Semi-transparent overlay
                                            ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                  Colors.black.withOpacity(0.5),
                                                  BlendMode.srcOut),
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                            color: Colors
                                                                .transparent,
                                                            backgroundBlendMode:
                                                                BlendMode
                                                                    .dstOut),
                                                  ),
                                                  Positioned(
                                                    left: left,
                                                    top: top,
                                                    child: Container(
                                                      width: scanWindowSize,
                                                      height: scanWindowSize,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Border for the scan window
                                            Positioned(
                                              left: left,
                                              top: top,
                                              child: Container(
                                                width: scanWindowSize,
                                                height: scanWindowSize,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color:
                                                          AppColors.zestyLime,
                                                      width: 3),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                      onDetect: (capture) async {
                                        if (isScanned) return;
                                        final List<Barcode> barcodes =
                                            capture.barcodes;
                                        for (final barcode in barcodes) {
                                          if (barcode.rawValue != null) {
                                            isScanned = true;
                                            // Haptic feedback or Sound could go here
                                            HapticFeedback.mediumImpact();

                                            // Show a success message briefly
                                            NanoToast.showSuccess(
                                                ctx, "QR Code Found!");

                                            // Small delay for UX
                                            await Future.delayed(const Duration(
                                                milliseconds: 800));

                                            if (ctx.mounted) {
                                              Navigator.pop(
                                                  ctx, barcode.rawValue);
                                            }
                                            break;
                                          }
                                        }
                                      },
                                    ),
                                    const Positioned(
                                      bottom: 50,
                                      left: 0,
                                      right: 0,
                                      child: Text(
                                        "Align QR code within the frame",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        );

                        if (!context.mounted) return;

                        if (code != null) {
                          _joinCodeController.text = code;
                          NanoToast.showSuccess(context, "Scanning Code...");
                          // Auto Join
                          await ref
                              .read(householdControllerProvider.notifier)
                              .joinHousehold(code.trim());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () async {
                      if (_joinCodeController.text.trim().isEmpty) {
                        NanoToast.showError(context, "Please enter a code");
                        return;
                      }
                      await ref
                          .read(householdControllerProvider.notifier)
                          .joinHousehold(_joinCodeController.text.trim());
                    },
                    child: Text(AppLocalizations.of(context)!.householdJoin),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView(Map<String, dynamic> household) {
    final householdId = household['id'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.zestyLime.withOpacity(0.2),
                Colors.transparent
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.zestyLime.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(household['name'] ?? "My Household",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Invite Code
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          householdId,
                          style: const TextStyle(
                              color: AppColors.zestyLime,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Copy Button
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white70),
                        tooltip: "Copy Code",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: householdId));
                          NanoToast.showSuccess(
                              context, "Code copied to clipboard!");
                        },
                      ),
                      // Share Button
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white70),
                        tooltip: "Share Code",
                        onPressed: () {
                          Share.share(
                              "Join my ChefMind household! Code: $householdId");
                        },
                      ),
                      // QR Button
                      IconButton(
                        icon: const Icon(Icons.qr_code,
                            color: AppColors.zestyLime),
                        tooltip: "Show QR Code",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              contentPadding: const EdgeInsets.all(24),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    household['name'] ?? "Household",
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: QrImageView(
                                      data: householdId,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text("Scan to Join",
                                      style: TextStyle(color: Colors.black54)),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Close"),
                                )
                              ],
                            ),
                          );
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.householdShareCode,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 32),
          // Members List
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ref
                .read(householdRepositoryProvider)
                .getMembersStream(householdId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // If offline, just show a friendly message or empty state
                if (snapshot.error.toString().contains('SocketException') ||
                    snapshot.error.toString().contains('Realtime')) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white54, size: 20),
                        SizedBox(width: 12),
                        Text("Members list unavailable while offline",
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }
                return Text("Error: ${snapshot.error}",
                    style: const TextStyle(color: AppColors.errorRed));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data!;
              final memberCount = members.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Members ($memberCount)",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      // Enhanced Display Logic
                      final email = member['email'] as String?;
                      // Prefer household_joined_at, fallback to created_at (which is account creation)
                      final joinedRaw = (member['household_joined_at'] ??
                          member['created_at']) as String?;
                      String joinedDate = "";

                      if (joinedRaw != null) {
                        try {
                          final date = DateTime.parse(joinedRaw);
                          joinedDate =
                              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                        } catch (e) {
                          joinedDate = "Unknown";
                        }
                      }

                      String? displayName =
                          member['full_name'] ?? member['first_name'];

                      // Fallback to email username if name is missing
                      if (displayName == null &&
                          email != null &&
                          email.contains('@')) {
                        displayName = email.split('@')[0];
                      }

                      // Ultimate fallback
                      displayName ??= "Member ${index + 1}";

                      // Add "Me" indicator
                      final currentUserId =
                          Supabase.instance.client.auth.currentUser?.id;
                      if (currentUserId != null &&
                          member['id'] == currentUserId) {
                        displayName = "Me - $displayName";
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.zestyLime,
                              backgroundImage: member['avatar_url'] != null
                                  ? NetworkImage(member['avatar_url'])
                                  : null,
                              child: member['avatar_url'] == null
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: AppColors.deepCharcoal,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Text(displayName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold))),
                            if (joinedDate.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("Joined",
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 10)),
                                  Text(joinedDate,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 48),
          Center(
            child: Consumer(builder: (context, ref, _) {
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final isCreator = currentUserId != null &&
                  household['created_by'] == currentUserId;

              if (isCreator) {
                return TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.deepCharcoal,
                              title: const Text("Delete Household?",
                                  style: TextStyle(color: Colors.white)),
                              content: const Text(
                                  "This will permanently delete the household and remove all members. Only you can do this.",
                                  style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Delete Forever",
                                        style: TextStyle(
                                            color: AppColors.errorRed))),
                              ],
                            ));
                    if (confirm == true) {
                      await ref
                          .read(householdControllerProvider.notifier)
                          .deleteHousehold(householdId);
                    }
                  },
                  icon: const Icon(Icons.delete_forever,
                      color: AppColors.errorRed),
                  label: const Text("Delete Household",
                      style: TextStyle(color: AppColors.errorRed)),
                );
              } else {
                return TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.deepCharcoal,
                              title: Text(
                                  AppLocalizations.of(context)!
                                      .householdLeaveConfirm,
                                  style: const TextStyle(color: Colors.white)),
                              content: Text(
                                  AppLocalizations.of(context)!
                                      .householdLeaveMessage,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                        AppLocalizations.of(context)!
                                            .householdLeaveButton,
                                        style: TextStyle(
                                            color: AppColors.errorRed))),
                              ],
                            ));
                    if (confirm == true) {
                      await ref
                          .read(householdControllerProvider.notifier)
                          .leaveHousehold();
                    }
                  },
                  icon:
                      const Icon(Icons.exit_to_app, color: AppColors.errorRed),
                  label: Text(AppLocalizations.of(context)!.householdLeave,
                      style: const TextStyle(color: AppColors.errorRed)),
                );
              }
            }),
          )
        ],
      ),
    );
  }
}
