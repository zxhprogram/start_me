import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GitHubAuthService {
  static const String _baseUrl = 'http://localhost:8080/api';
  static const String _tokenKey = 'github_token';
  static const String _userKey = 'github_user';

  /// 获取 OAuth 授权 URL
  static Future<String?> getOAuthUrl() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/github/oauth/url'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['url'] as String;
        }
      }
      return null;
    } catch (e) {
      print('Error getting OAuth URL: $e');
      return null;
    }
  }

  /// 轮询获取 OAuth token
  static Future<String?> pollToken() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/github/oauth/token/poll'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          return data['token'] as String;
        }
      }
      return null;
    } catch (e) {
      print('Error polling token: $e');
      return null;
    }
  }

  /// 轮询直到获取到 token（超时 120 秒）
  static Future<String?> waitForToken() async {
    const maxAttempts = 60;
    for (int i = 0; i < maxAttempts; i++) {
      final token = await pollToken();
      if (token != null) return token;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  /// 获取 GitHub 用户信息
  static Future<Map<String, String>?> getUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/github/user'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final user = data['data'];
          return {
            'login': user['login'] ?? '',
            'avatar_url': user['avatar_url'] ?? '',
            'name': user['name'] ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting GitHub user: $e');
      return null;
    }
  }

  /// 获取用户 star 列表（分页）
  /// 返回 {data: List<Map>, hasMore: bool}
  static Future<Map<String, dynamic>> getUserStars(String token, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/github/stars?page=$page'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'data': List<Map<String, dynamic>>.from(data['data']),
            'hasMore': data['has_more'] == true,
          };
        }
      }
      return {'data': <Map<String, dynamic>>[], 'hasMore': false};
    } catch (e) {
      print('Error getting user stars: $e');
      return {'data': <Map<String, dynamic>>[], 'hasMore': false};
    }
  }

  /// 获取用户 Feed（分页）
  static Future<Map<String, dynamic>> getUserFeed(String token, {int page = 1, String? login}) async {
    try {
      var url = '$_baseUrl/github/feed?page=$page';
      if (login != null && login.isNotEmpty) {
        url += '&login=$login';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'data': List<Map<String, dynamic>>.from(data['data']),
            'hasMore': data['has_more'] == true,
          };
        }
      }
      return {'data': <Map<String, dynamic>>[], 'hasMore': false};
    } catch (e) {
      print('Error getting user feed: $e');
      return {'data': <Map<String, dynamic>>[], 'hasMore': false};
    }
  }

  /// 保存 token 到本地
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 从本地获取 token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 清除 token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// 保存用户信息到本地
  static Future<void> saveUser(Map<String, String> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// 从本地获取用户信息
  static Future<Map<String, String>?> getUser_local() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      final decoded = jsonDecode(userStr);
      return Map<String, String>.from(decoded);
    }
    return null;
  }
}
