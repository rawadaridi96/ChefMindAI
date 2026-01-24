import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/nano_toast.dart';

class ChefLabsScreen extends ConsumerStatefulWidget {
  const ChefLabsScreen({super.key});

  @override
  ConsumerState<ChefLabsScreen> createState() => _ChefLabsScreenState();
}

class _ChefLabsScreenState extends ConsumerState<ChefLabsScreen> {
  // Feature flags
  bool _voiceModeEnabled = false;
  bool _smartFridgeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceModeEnabled = prefs.getBool('beta_voice_mode') ?? false;
      _smartFridgeEnabled = prefs.getBool('beta_smart_fridge') ?? false;
    });
  }

  Future<void> _toggleSetting(String key, bool value,
      {required VoidCallback onSuccess}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    onSuccess();
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

            // Voice Mode (Existing)
            _buildToggleTile(
              title: "Voice Mode",
              description:
                  "Speak to your AI Chef instead of typing. Currently a visual prototype.",
              icon: Icons.mic,
              value: _voiceModeEnabled,
              onChanged: (val) => _toggleSetting('beta_voice_mode', val,
                  onSuccess: () => setState(() => _voiceModeEnabled = val)),
            ),

            // Smart Fridge Link
            _buildToggleTile(
              title: "Smart Fridge Link",
              description:
                  "Connect to supported smart fridges to auto-sync inventory.",
              icon: Icons.kitchen,
              value: _smartFridgeEnabled,
              onChanged: (val) {
                _toggleSetting('beta_smart_fridge', val, onSuccess: () {
                  setState(() => _smartFridgeEnabled = val);
                  if (val) {
                    NanoToast.showInfo(
                        context, "Scanning for smart fridges...");
                  }
                });
              },
            ),

            const SizedBox(height: 8),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),

            // Link Scraper
            _buildActionTile(
              title: "Recipe Link Scraper",
              description:
                  "Paste a video or blog link to generate a ChefMind recipe.",
              icon: Icons.link,
              actionLabel: "Paste Link",
              onTap: _showLinkScraperDialog,
            ),

            // Diet Plan Upload
            _buildActionTile(
              title: "Upload Diet Plan",
              description:
                  "Upload a text or image of your diet plan for tailored suggestions.",
              icon: Icons.upload_file,
              actionLabel: "Upload",
              onTap: _showDietPlanUploadDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
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

  Widget _buildActionTile({
    required String title,
    required String description,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white54,
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
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.zestyLime.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.zestyLime.withOpacity(0.4)),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
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

  void _showLinkScraperDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.deepCharcoal,
        title: const Text("Recipe Link Scraper",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Paste a URL from YouTube, Instagram, or a food blog.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "https://...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
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
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                NanoToast.showInfo(context, "Analyzing content... (Mock)");
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zestyLime,
                foregroundColor: AppColors.deepCharcoal),
            child: const Text("Analyze"),
          )
        ],
      ),
    );
  }

  void _showDietPlanUploadDialog() {
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
            const Text(
              "Upload Diet Plan",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Upload a PDF, image, or paste text of your diet plan. ChefMind will create recipes that fit your plan.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildUploadOption(
                    icon: Icons.camera_alt,
                    label: "Scan Image",
                    onTap: () {
                      Navigator.pop(context);
                      NanoToast.showInfo(context, "Scanning... (Mock)");
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUploadOption(
                    icon: Icons.text_fields,
                    label: "Paste Text",
                    onTap: () {
                      Navigator.pop(context);
                      NanoToast.showInfo(context, "Processing text... (Mock)");
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.zestyLime, size: 32),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
