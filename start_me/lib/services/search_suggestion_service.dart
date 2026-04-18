import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchSuggestionService {
  static const String _baseUrl = 'http://localhost:8080/api';

  static Future<List<String>> getSuggestions(
    String query, {
    String engine = '百度',
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/search/suggestions').replace(
        queryParameters: {'q': query, 'engine': engine},
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<String>.from(data['data']);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
