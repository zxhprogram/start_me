import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;

class CardOrderService {
  static const String _baseUrl = 'http://localhost:8080/api';
  static const String _localKey = 'card_order';
  static const String _settingsKey = 'card_order';

  /// 获取卡片顺序
  /// 优先从服务器获取（如果已登录），否则从本地获取
  static Future<List<String>?> getCardOrder() async {
    // 检查是否已登录
    if (AuthService.token.isNotEmpty) {
      // 已登录，从服务器获取
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/user/settings/$_settingsKey'),
          headers: AuthService.getAuthHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final value = data['data']['value'] as String?;
            if (value != null && value.isNotEmpty) {
              return List<String>.from(jsonDecode(value));
            }
          }
        }
      } catch (e) {
        // 服务器获取失败，回退到本地
      }
    }

    // 未登录或服务器获取失败，从本地获取
    return _getLocalCardOrder();
  }

  /// 保存卡片顺序
  /// 如果已登录，保存到服务器；否则保存到本地
  static Future<bool> saveCardOrder(List<String> order) async {
    final jsonValue = jsonEncode(order);

    // 检查是否已登录
    if (AuthService.token.isNotEmpty) {
      // 已登录，保存到服务器
      try {
        final response = await http.put(
          Uri.parse('$_baseUrl/user/settings/$_settingsKey'),
          headers: AuthService.getAuthHeaders(),
          body: jsonEncode({'value': jsonValue}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            // 同时更新本地缓存，保持同步
            await _saveLocalCardOrder(order);
            return true;
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    } else {
      // 未登录，保存到本地
      return _saveLocalCardOrder(order);
    }
  }

  /// 从本地获取卡片顺序
  static Future<List<String>?> _getLocalCardOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_localKey);
      if (value != null && value.isNotEmpty) {
        return List<String>.from(jsonDecode(value));
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 保存到本地
  static Future<bool> _saveLocalCardOrder(List<String> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonValue = jsonEncode(order);
      return await prefs.setString(_localKey, jsonValue);
    } catch (e) {
      return false;
    }
  }

  /// 清除本地缓存（通常在登录成功后调用，用于同步服务器数据）
  static Future<void> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localKey);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 同步本地数据到服务器（登录后调用）
  static Future<void> syncToServer() async {
    if (AuthService.token.isEmpty) return;

    final localOrder = await _getLocalCardOrder();
    if (localOrder != null && localOrder.isNotEmpty) {
      // 保存到服务器
      final success = await saveCardOrder(localOrder);
      if (success) {
        // 同步成功后清除本地缓存
        await clearLocalCache();
      }
    }
  }
}
