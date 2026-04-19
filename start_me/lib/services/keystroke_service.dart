import 'dart:convert';
import 'package:http/http.dart' as http;

class KeystrokeService {
  static const String _baseUrl = 'http://localhost:8080/api';

  static Future<List<Map<String, dynamic>>> getTopKeys({
    String period = 'today',
    int limit = 3,
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/keystrokes/top?period=$period&limit=$limit'),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> getAllKeys({String? date}) async {
    try {
      final query = date != null ? '?date=$date' : '';
      final resp = await http.get(
        Uri.parse('$_baseUrl/keystrokes/all$query'),
      );
      final result = jsonDecode(resp.body);
      if (result['success'] == true) {
        final rawData = result['data'] as Map<String, dynamic>? ?? {};
        final data = rawData.map((k, v) => MapEntry(k, (v as num).toInt()));
        final dates = List<String>.from(result['dates'] ?? []);
        return {
          'data': data,
          'date': result['date'] ?? '',
          'dates': dates,
        };
      }
    } catch (_) {}
    return {'data': <String, int>{}, 'date': date ?? '', 'dates': <String>[]};
  }

  static Future<bool> syncCounts(Map<String, int> counts) async {
    if (counts.isEmpty) return true;
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/keystrokes/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'counts': counts}),
      );
      final data = jsonDecode(resp.body);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
