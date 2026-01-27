import 'dart:convert';
import 'package:http/http.dart' as http;

class PexelsService {
  // TODO: Replace with your actual Pexels API Key
  static const String _apiKey =
      'O9AVo96FcCsGhNHfBN98Sr07F3FpZvTFtAjMpk6eU00VRRhOtds0ZwBK';
  static const String _baseUrl = 'https://api.pexels.com/v1/search';

  static Future<String?> searchImage(String query,
      {String orientation = 'landscape', String suffix = 'food'}) async {
    if (query.isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'query': "$query $suffix", // Add context
        'per_page': '1',
        'orientation': orientation,
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
          // Return the 'medium' or 'large' src
          return data['photos'][0]['src']['medium'];
        }
      }
    } catch (e) {
      // Silently fail on error (offline, quota, etc)
      print("Pexels Error: $e");
    }
    return null;
  }
}
