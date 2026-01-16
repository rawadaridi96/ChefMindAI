import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'scanner_controller.dart';
import '../../pantry/presentation/pantry_controller.dart';
import '../../../../core/widgets/nano_toast.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();

    // Pulsing Animation Setup
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium, // Speed > Quality for ingredients
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();
    await _initializeControllerFuture;

    if (mounted) {
      setState(() => _isCameraReady = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isCameraReady || _controller == null) return;

    try {
      final image = await _controller!.takePicture();
      final file = File(image.path);

      // Trigger scan
      ref.read(scannerControllerProvider.notifier).scanImage(file);

      // Wait for result and show sheet
      if (mounted) {
        _waitForResultAndShowSheet();
      }
    } catch (e) {
      NanoToast.showError(context, 'Error: $e');
    }
  }

  void _waitForResultAndShowSheet() {
    // Listen to state changes to know when to show the sheet
    ref.listenManual(scannerControllerProvider, (previous, next) {
      if (next.hasValue && next.value != null && !next.isLoading) {
        // Show review sheet
        _showReviewSheet(next.value!);
      }
    });
  }

  void _showReviewSheet(List<String> detectedItems) {
    // Need a local state for selection
    final selectedItems = Set<String>.from(detectedItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: AppColors.deepCharcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Found These Items 🥦',
                    style: TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uncheck any mistakes before adding.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  // List
                  Expanded(
                    child: ListView.builder(
                      itemCount: detectedItems.length,
                      itemBuilder: (context, index) {
                        final item = detectedItems[index];
                        final isSelected = selectedItems.contains(item);
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: AppColors.zestyLime,
                          checkColor: AppColors.deepCharcoal,
                          title: Text(item,
                              style: const TextStyle(color: Colors.white)),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedItems.add(item);
                              } else {
                                selectedItems.remove(item);
                              }
                            });
                          },
                          secondary: const Icon(Icons.food_bank,
                              color: Colors.white54),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.zestyLime,
                        foregroundColor: AppColors.deepCharcoal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ref
                            .read(pantryControllerProvider.notifier)
                            .addIngredients(selectedItems.toList());
                        Navigator.pop(context); // Close sheet
                        Navigator.pop(context); // Close scanner
                        NanoToast.showSuccess(context,
                            'Added ${selectedItems.length} items to Pantry!');
                        // Reset scanner
                        ref.read(scannerControllerProvider.notifier).reset();
                      },
                      child: Text('Add ${selectedItems.length} Items to Pantry',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera with Pulsing Border
          if (_isCameraReady)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: scanState.isLoading ? _pulseAnimation.value : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        border: scanState.isLoading
                            ? Border.all(color: AppColors.zestyLime, width: 4)
                            : null,
                      ),
                      child: CameraPreview(_controller!),
                    ),
                  );
                },
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const GlassContainer(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        borderRadius: 20,
                        child: Text(
                          'Vision Scanner',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const Spacer(),

                // Loading Text or Capture Button
                if (scanState.isLoading)
                  _buildLoadingState()
                else
                  _buildCaptureButton(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Center(
      child: GestureDetector(
        onTap: _takePicture,
        child: Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: Colors.white24,
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.zestyLime,
            ),
            child: const Icon(Icons.camera_alt,
                color: AppColors.deepCharcoal, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.zestyLime),
          SizedBox(height: 16),
          Text("AI is analyzing...", style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
