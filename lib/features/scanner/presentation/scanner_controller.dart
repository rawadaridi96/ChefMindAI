import 'dart:io';
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

      // 2. Analyze
      final ingredients = await repository.analyzeImage(imagePath);

      state = AsyncData(ingredients);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}
