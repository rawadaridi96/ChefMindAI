import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChefLabsScreen extends ConsumerStatefulWidget {
  const ChefLabsScreen({super.key});

  @override
  ConsumerState<ChefLabsScreen> createState() => _ChefLabsScreenState();
}

class _ChefLabsScreenState extends ConsumerState<ChefLabsScreen> {
  bool _voiceModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceModeEnabled = prefs.getBool('beta_voice_mode') ?? false;
    });
  }

  Future<void> _toggleVoiceMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('beta_voice_mode', value);
    setState(() {
      _voiceModeEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepCharcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.science, color: AppColors.zestyLime, size: 20),
            const SizedBox(width: 8),
            const Text(
              "ChefLabs",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.zestyLime.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.zestyLime.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.zestyLime, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "These features are experimental. They may change, break, or disappear at any time.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Available Experiments",
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            _buildBetaTile(
              title: "Voice Mode",
              description:
                  "Speak to your AI Chef instead of typing. Currently a visual prototype.",
              icon: Icons.mic,
              value: _voiceModeEnabled,
              onChanged: _toggleVoiceMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBetaTile({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? AppColors.zestyLime : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.zestyLime
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: value ? AppColors.deepCharcoal : Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: value,
                activeColor: AppColors.zestyLime,
                activeTrackColor: AppColors.zestyLime.withOpacity(0.2),
                inactiveThumbColor: Colors.white54,
                inactiveTrackColor: Colors.white10,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
