import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:8080/api';
  static String _token = '';

  static String get token => _token;

  static Map<String, String> getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token') ?? '';
  }

  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// 用户名密码注册
  static Future<Map<String, dynamic>?> register(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _saveToken(data['token'] as String);
        return data['user'] as Map<String, dynamic>;
      }
      throw Exception(data['error'] ?? '注册失败');
    } catch (e) {
      rethrow;
    }
  }

  /// 用户名密码登录
  static Future<Map<String, dynamic>?> login(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _saveToken(data['token'] as String);
        return data['user'] as Map<String, dynamic>;
      }
      throw Exception(data['error'] ?? '登录失败');
    } catch (e) {
      rethrow;
    }
  }

  /// GitHub 第三方登录
  static Future<Map<String, dynamic>?> githubLogin(
      String githubAccessToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/github'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': githubAccessToken}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _saveToken(data['token'] as String);
        return data['user'] as Map<String, dynamic>;
      }
      throw Exception(data['error'] ?? 'GitHub 登录失败');
    } catch (e) {
      rethrow;
    }
  }

  /// 获取当前用户信息
  static Future<Map<String, dynamic>?> getProfile() async {
    if (_token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: getAuthHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['user'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
