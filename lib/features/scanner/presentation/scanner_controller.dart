import 'dart:io';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/scanner_repository.dart';

part 'scanner_controller.g.dart';

@riverpod
class ScannerController extends _$ScannerController {
  @override
  FutureOr<List<String>?> build() {
    return null; // Null means no scan results yet
  }

  Future<void> scanImage(File image) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(scannerRepositoryProvider);

      // 1. Upload
      final imagePath = await repository.uploadImage(image);

      // 2. Analyze with Timeout
      final ingredients = await repository
          .analyzeImage(imagePath)
          .timeout(const Duration(seconds: 10));

      state = AsyncData(ingredients);
    } catch (e, st) {
      // Fallback for Demo/Testing if backend/storage fails
      // Removed Mock Fallback as per user request
      state = AsyncError(e, st);
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}
