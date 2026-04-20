import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class BookmarkFolderService {
  static const String _baseUrl = 'http://localhost:8080/api';

  /// 创建文件夹
  /// [groupId] 分组ID
  /// [name] 文件夹名称
  /// [sortOrder] 排序位置
  /// [bookmarkIds] 要放入文件夹的书签ID列表
  static Future<Map<String, dynamic>?> createFolder({
    required int groupId,
    required String name,
    required int sortOrder,
    required List<int> bookmarkIds,
  }) async {
    if (AuthService.token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/bookmarks/folders'),
        headers: AuthService.getAuthHeaders(),
        body: jsonEncode({
          'group_id': groupId,
          'name': name,
          'sort_order': sortOrder,
          'bookmark_ids': bookmarkIds,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 重命名文件夹
  static Future<bool> renameFolder(int folderId, String newName) async {
    if (AuthService.token.isEmpty) return false;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/bookmarks/folders/$folderId'),
        headers: AuthService.getAuthHeaders(),
        body: jsonEncode({'name': newName}),
      );

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 删除文件夹（书签移出）
  static Future<bool> deleteFolder(int folderId) async {
    if (AuthService.token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/bookmarks/folders/$folderId'),
        headers: AuthService.getAuthHeaders(),
      );

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 获取文件夹列表
  static Future<List<Map<String, dynamic>>?> getFolders(int groupId) async {
    if (AuthService.token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/bookmarks/folders?group_id=$groupId'),
        headers: AuthService.getAuthHeaders(),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 移动书签到文件夹
  static Future<bool> moveBookmarksToFolder(
    int folderId,
    List<int> bookmarkIds,
  ) async {
    if (AuthService.token.isEmpty) return false;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/bookmarks/folders/$folderId/bookmarks'),
        headers: AuthService.getAuthHeaders(),
        body: jsonEncode({'bookmark_ids': bookmarkIds}),
      );

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 将书签移出文件夹
  static Future<bool> moveBookmarksOutOfFolder(List<int> bookmarkIds) async {
    if (AuthService.token.isEmpty) return false;

    try {
      // 使用 DELETE 请求移出文件夹
      final response = await http.delete(
        Uri.parse('$_baseUrl/bookmarks/folders/0/bookmarks'),
        headers: AuthService.getAuthHeaders(),
        body: jsonEncode({'bookmark_ids': bookmarkIds}),
      );

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
