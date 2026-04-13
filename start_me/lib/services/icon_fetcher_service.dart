import 'dart:convert';
import 'package:http/http.dart' as http;

class IconData {
  final String title;
  final String? favicon;
  final String? description;

  IconData({required this.title, this.favicon, this.description});

  factory IconData.fromJson(Map<String, dynamic> json) {
    return IconData(
      title: json['title'] ?? '',
      favicon: json['favicon'],
      description: json['description'],
    );
  }
}

class IconFetcherService {
  static const String _baseUrl = 'http://localhost:8080/api';

  /// 抓取网页信息
  static Future<IconData?> fetchWebInfo(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fetch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return IconData.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching web info: $e');
      return null;
    }
  }

  /// 获取代理图标 URL
  static String getProxyIconUrl(String iconUrl) {
    return '$_baseUrl/proxy/icon?url=${Uri.encodeComponent(iconUrl)}';
  }
}
