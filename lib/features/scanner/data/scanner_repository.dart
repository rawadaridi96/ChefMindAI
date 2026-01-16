import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'scanner_repository.g.dart';

@riverpod
ScannerRepository scannerRepository(ScannerRepositoryRef ref) {
  return ScannerRepository(Supabase.instance.client);
}

class ScannerRepository {
  final SupabaseClient _client;

  ScannerRepository(this._client);

  Future<String> uploadImage(File image) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'scans/$fileName';

    await _client.storage.from('images').upload(
          path,
          image,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    return path;
  }

  Future<List<String>> analyzeImage(String imagePath) async {
    final response = await _client.functions.invoke(
      'analyze-fridge', // Assumed function name based on "setup" status
      body: {'image_path': imagePath},
    );

    if (response.status != 200) {
      throw Exception('Failed to analyze image: ${response.status}');
    }

    final data = response.data;
    if (data is Map && data.containsKey('ingredients')) {
      return List<String>.from(data['ingredients']);
    } else {
      // Fallback or empty if structure is different
      return [];
    }
  }
}
