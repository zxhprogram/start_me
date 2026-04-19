import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EmailService {
  static const String _baseUrl = 'http://localhost:8080/api';

  static Future<Map<String, dynamic>?> getConfig() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/email/config'),
        headers: AuthService.getAuthHeaders(),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return data['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> saveConfig({
    required String host,
    required int port,
    required String username,
    required String password,
    required bool useTls,
  }) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/email/config'),
      headers: AuthService.getAuthHeaders(),
      body: jsonEncode({
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'use_tls': useTls,
      }),
    );
    final data = jsonDecode(resp.body);
    if (data['success'] == true) return true;
    throw Exception(data['error'] ?? '保存失败');
  }

  static Future<bool> deleteConfig() async {
    try {
      final resp = await http.delete(
        Uri.parse('$_baseUrl/email/config'),
        headers: AuthService.getAuthHeaders(),
      );
      final data = jsonDecode(resp.body);
      return data['success'] == true;
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> getEmails({int page = 1, int pageSize = 20}) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/email/list?page=$page&page_size=$pageSize'),
        headers: AuthService.getAuthHeaders(),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true && data['data'] != null) {
        final d = data['data'];
        return {
          'emails': List<Map<String, dynamic>>.from(d['emails'] ?? []),
          'total': d['total'] ?? 0,
          'page': d['page'] ?? page,
          'page_size': d['page_size'] ?? pageSize,
        };
      }
    } catch (_) {}
    return {'emails': <Map<String, dynamic>>[], 'total': 0, 'page': page, 'page_size': pageSize};
  }

  static Future<Map<String, dynamic>?> getEmailDetail(int emailId) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/email/detail/$emailId'),
        headers: AuthService.getAuthHeaders(),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
