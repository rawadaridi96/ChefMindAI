import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:chefmind_ai/core/widgets/glass_container.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  bool _cameraUnavailable = false;
  File? _capturedImage;
  bool _isPickingImage = false;

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
    if (cameras.isEmpty) {
      if (mounted) setState(() => _cameraUnavailable = true);
      return;
    }

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
      setState(() => _capturedImage = file); // Freeze UI
      _processImage(file);
    } catch (e) {
      NanoToast.showError(context, 'Error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isPickingImage = true); // Show spinner
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      // Preload image to avoid black screen / double loading
      if (mounted) {
        await precacheImage(FileImage(file), context);
      }

      setState(() {
        _capturedImage = file;
        _isPickingImage = false;
      }); // Show Image

      // Small delay to let UI render the image before showing "Analyzing" overlay
      await Future.delayed(const Duration(milliseconds: 100));

      _processImage(file); // Start Analysis
    } else {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _processImage(File file) async {
    // Trigger scan
    ref.read(scannerControllerProvider.notifier).scanImage(file);

    // Wait for result and show sheet
    if (mounted) {
      _waitForResultAndShowSheet();
    }
  }

  void _waitForResultAndShowSheet() {
    // Listen to state changes to know when to show the sheet
    ref.listenManual(scannerControllerProvider, (previous, next) {
      if (next.hasValue && next.value != null && !next.isLoading) {
        // Show review sheet
        _showReviewSheet(next.value!);
      } else if (next.hasError && !next.isLoading) {
        // Handle Error
        NanoToast.showError(context, "Scan failed: ${next.error}");
        // Reset state so user can try again
        ref.read(scannerControllerProvider.notifier).reset();
        setState(() => _capturedImage = null); // Unfreeze UI
      }
    });
  }

  void _showReviewSheet(List<String> detectedItems) {
    // 1. Get current pantry items to find duplicates
    final pantryItems = ref.read(pantryControllerProvider).value ?? [];
    final existingNames = pantryItems
        .map((item) => (item['name'] as String).toLowerCase())
        .toSet();

    // 2. Initialize selection (Only check NEW items)
    final selectedItems = <String>{};
    for (var item in detectedItems) {
      if (!existingNames.contains(item.toLowerCase())) {
        selectedItems.add(item);
      }
    }

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
                  Text(
                    AppLocalizations.of(context)!.scannerAIFoundItems,
                    style: const TextStyle(
                        color: AppColors.zestyLime,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.scannerUncheckMistakes,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  // List
                  Expanded(
                    child: ListView.builder(
                      itemCount: detectedItems.length,
                      itemBuilder: (context, index) {
                        final item = detectedItems[index];
                        final isDuplicate =
                            existingNames.contains(item.toLowerCase());
                        final isSelected = selectedItems.contains(item);

                        return CheckboxListTile(
                          value: isDuplicate ? false : isSelected,
                          // Disable if duplicate
                          onChanged: isDuplicate
                              ? null
                              : (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      selectedItems.add(item);
                                    } else {
                                      selectedItems.remove(item);
                                    }
                                  });
                                },
                          activeColor: AppColors.zestyLime,
                          checkColor: AppColors.deepCharcoal,
                          title: Text(
                            item,
                            style: TextStyle(
                              color:
                                  isDuplicate ? Colors.white38 : Colors.white,
                              decoration: isDuplicate
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: isDuplicate
                              ? Text(
                                  AppLocalizations.of(context)!
                                      .scannerItemAlreadyInPantry,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12),
                                )
                              : null,
                          secondary: Icon(Icons.food_bank,
                              color: isDuplicate
                                  ? Colors.white24
                                  : Colors.white54),
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
                      onPressed: selectedItems.isEmpty
                          ? null
                          : () async {
                              final addedCount = await ref
                                  .read(pantryControllerProvider.notifier)
                                  .addIngredients(selectedItems.toList());

                              Navigator.pop(context); // Close sheet
                              Navigator.pop(context); // Close scanner

                              NanoToast.showSuccess(
                                  context,
                                  AppLocalizations.of(context)!
                                      .scannerAddedToPantry(addedCount));

                              // Reset scanner
                              ref
                                  .read(scannerControllerProvider.notifier)
                                  .reset();
                              setState(
                                  () => _capturedImage = null); // Unfreeze UI
                            },
                      child: Text(
                          AppLocalizations.of(context)!
                              .scannerAddItemsToPantry(selectedItems.length),
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
          if (_isPickingImage)
            const Center(
                child: CircularProgressIndicator(color: AppColors.zestyLime))
          else if (_cameraUnavailable)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined,
                      size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.scannerCameraUnavailable,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label:
                        Text(AppLocalizations.of(context)!.scannerFromGallery),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.zestyLime,
                      foregroundColor: AppColors.deepCharcoal,
                    ),
                  )
                ],
              ),
            )
          else if (_capturedImage != null)
            Center(
                child: Image.file(
              _capturedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.zestyLime));
              },
            ))
          else if (_isCameraReady)
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
            const Center(
                child: CircularProgressIndicator(color: AppColors.zestyLime)),

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
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        borderRadius: 20,
                        child: Text(
                          AppLocalizations.of(context)!.scannerVisionScanner,
                          style: const TextStyle(
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
                else if (!_cameraUnavailable)
                  // Capture Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library,
                            color: Colors.white, size: 32),
                        tooltip: "Gallery",
                      ),
                      _buildCaptureButton(),
                      const SizedBox(width: 48), // Balance spacing
                    ],
                  ),

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
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.zestyLime),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.scannerAnalyzing,
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
