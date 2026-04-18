import 'dart:convert';
import 'package:http/http.dart' as http;

class HotSearchService {
  static const String _baseUrl = 'http://localhost:8080/api';

  /// 获取指定节点的热搜数据
  static Future<Map<String, dynamic>> getHotTopics(
    int nodeId, {
    String? date,
  }) async {
    try {
      var url = '$_baseUrl/tophub/hot?nodeid=$nodeId';
      if (date != null) url += '&date=$date';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
            'sitename': data['sitename'] ?? '',
            'logo': data['logo'] ?? '',
          };
        }
      }
      return {'data': <Map<String, dynamic>>[], 'sitename': '', 'logo': ''};
    } catch (_) {
      return {'data': <Map<String, dynamic>>[], 'sitename': '', 'logo': ''};
    }
  }

  /// 获取所有可用数据源节点
  static Future<List<Map<String, dynamic>>> getNodes({
    String? category,
  }) async {
    try {
      var url = '$_baseUrl/tophub/nodes';
      if (category != null) url += '?category=$category';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
