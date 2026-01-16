import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ConflictResolutionDialog extends StatelessWidget {
  final String title;
  final VoidCallback onOverwrite;
  final VoidCallback onSaveAsNew;
  final VoidCallback onCancel;

  const ConflictResolutionDialog({
    super.key,
    required this.title,
    required this.onOverwrite,
    required this.onSaveAsNew,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.deepCharcoal.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.zestyLime, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Duplicate Recipe",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  "A recipe named \"$title\" already exists in your Vault.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  "What would you like to do?",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Preview Cards Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10)),
                        child: const Column(
                          children: [
                            Text("Existing",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            SizedBox(height: 4),
                            Text("Original",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward,
                          color: Colors.white24, size: 16),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.zestyLime.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.zestyLime)),
                        child: const Column(
                          children: [
                            Text("New Version",
                                style: TextStyle(
                                    color: AppColors.zestyLime, fontSize: 12)),
                            SizedBox(height: 4),
                            Text("Updated",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSaveAsNew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.zestyLime,
                      foregroundColor: AppColors.deepCharcoal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save as New",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onOverwrite,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Overwrite Existing"),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onCancel,
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
