import 'dart:convert';
import 'package:http/http.dart' as http;

/// 备忘录数据模型
class Memo {
  final int id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Memo({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Memo.fromJson(Map<String, dynamic> json) {
    return Memo(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// 备忘录服务
class MemoService {
  static const String _baseUrl = 'http://localhost:8080/api';

  /// 获取所有备忘录
  static Future<List<Memo>> fetchMemos() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/memos'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => Memo.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching memos: $e');
      return [];
    }
  }

  /// 创建备忘录
  static Future<Memo?> createMemo(String content) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/memos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Memo.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error creating memo: $e');
      return null;
    }
  }

  /// 删除备忘录
  static Future<bool> deleteMemo(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/memos/$id'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting memo: $e');
      return false;
    }
  }

  /// 更新备忘录
  static Future<Memo?> updateMemo(int id, String content) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/memos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Memo.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error updating memo: $e');
      return null;
    }
  }
}
