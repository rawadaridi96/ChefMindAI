import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/nano_toast.dart';
import '../../../../core/services/offline_manager.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // Read only
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateChangesProvider).asData?.value.session?.user;
    if (user != null) {
      _emailController.text = user.email ?? '';

      final metadata = user.userMetadata;
      if (metadata != null && metadata.containsKey('full_name')) {
        _nameController.text = metadata['full_name'].toString();
      } else if (metadata != null && metadata.containsKey('name')) {
        _nameController.text = metadata['name'].toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final isConnected = ref.read(offlineManagerProvider).hasConnection;
    if (!isConnected) {
      NanoToast.showInfo(context, "No connection. Please check your internet.");
      return;
    }

    if (newName.isEmpty) {
      NanoToast.showError(context, "Name cannot be empty");
      return;
    }

    if (newPassword.isNotEmpty) {
      final passwordError = Validators.validatePassword(newPassword);
      if (passwordError != null) {
        NanoToast.showError(context, passwordError);
        return;
      }
      if (newPassword != confirmPassword) {
        NanoToast.showError(context, "Passwords do not match");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Call controller
      await ref.read(authControllerProvider.notifier).updateProfile(
          fullName: newName,
          password: newPassword.isNotEmpty ? newPassword : null);

      if (mounted) {
        NanoToast.showSuccess(context, "Profile updated successfully");
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        NanoToast.showError(context, e.message);
      }
    } catch (e) {
      // Catch unexpected errors
      if (mounted) {
        final error = e.toString().replaceAll('Exception:', '').trim();
        NanoToast.showError(context, "Update failed: $error");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeProfilePic() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.zestyLime),
              title: const Text("Choose from Library",
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(sheetContext); // Pop the sheet
                final picker = ImagePicker();
                try {
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.gallery);

                  if (pickedFile != null) {
                    setState(() => _isLoading = true);
                    try {
                      await ref
                          .read(authControllerProvider.notifier)
                          .uploadProfilePicture(File(pickedFile.path));

                      if (mounted)
                        NanoToast.showSuccess(context,
                            "Profile picture updated"); // Use widget context
                    } catch (e) {
                      if (mounted)
                        NanoToast.showError(context,
                            "Upload failed: ${e.toString().replaceAll('StorageException:', '').trim()}"); // Use widget context
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
                } catch (e) {
                  if (mounted)
                    NanoToast.showError(context, "Could not open gallery: $e");
                }
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.errorRed),
              title: const Text("Remove Photo",
                  style: TextStyle(color: AppColors.errorRed)),
              onTap: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(authControllerProvider.notifier)
                      .removeProfilePicture();
                  if (mounted)
                    NanoToast.showSuccess(context, "Profile picture removed");
                } catch (e) {
                  if (mounted)
                    NanoToast.showError(context, "Failed to remove image");
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authStateChangesProvider).asData?.value.session?.user;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        title: const Text("Edit Profile",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: AppColors.zestyLime, strokeWidth: 2))
                : const Text("Save",
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _isLoading ? null : _changeProfilePic,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.zestyLime, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white10,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.camera_alt_outlined,
                                size: 40, color: Colors.white)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.zestyLime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppColors.deepCharcoal),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField("Full Name", _nameController,
                textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            _buildTextField("Email", _emailController,
                readOnly: true, icon: Icons.lock_outline),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 32),
            const SizedBox(height: 8),
            const Text("Security",
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField("New Password", _passwordController,
                isPassword: true, hint: "Leave blank to keep current"),
            const SizedBox(height: 16), // Spacing
            _buildTextField("Confirm Password", _confirmPasswordController,
                isPassword: true, hint: "Re-enter new password"),
            const SizedBox(height: 8),
            const Text("Enter a new password only if you want to change it.",
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool readOnly = false,
      bool isPassword = false,
      String? hint,
      TextCapitalization textCapitalization = TextCapitalization.none,
      IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: isPassword,
          textCapitalization: textCapitalization,
          style: TextStyle(color: readOnly ? Colors.white38 : Colors.white),
          cursorColor: AppColors.zestyLime,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            suffixIcon: icon != null
                ? Icon(icon, color: Colors.white24, size: 18)
                : null,
            filled: true,
            fillColor: readOnly
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.zestyLime)),
          ),
        )
      ],
    );
  }
}
