import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsService {
  static const String _baseUrl = 'http://localhost:8080/api';

  static Future<String?> get(String key) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/settings/$key'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['value'] as String?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> set(String key, String value) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/settings/$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'value': value}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
