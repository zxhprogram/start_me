import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../signals/app_signal.dart';

class BookmarkService {
  static const String _baseUrl = 'http://localhost:8080/api';

  // Icon name <-> IconData mapping
  static final Map<String, IconData> _nameToIcon = {
    'home': Icons.home,
    'favorite': Icons.favorite,
    'music': Icons.music_note,
    'chat': Icons.chat,
    'work': Icons.work,
    'work_outline': Icons.work_outline,
    'movie': Icons.movie,
    'shopping': Icons.shopping_bag,
    'shopping_bag': Icons.shopping_bag,
    'code': Icons.code,
    'school': Icons.school,
    'book': Icons.book,
    'build': Icons.build,
    'like': Icons.thumb_up,
    'star': Icons.star,
    'hospital': Icons.local_hospital,
    'flight': Icons.flight,
    'article': Icons.article,
    'grid': Icons.grid_view,
    'eco': Icons.eco,
    'image': Icons.image,
    'award': Icons.emoji_events,
    'fitness': Icons.fitness_center,
    'parking': Icons.local_parking,
    'send': Icons.send,
    'flag': Icons.flag,
    'bookmark': Icons.bookmark,
    'delete': Icons.delete_outline,
    'folder': Icons.folder,
    'design_services': Icons.design_services,
    'navigation': Icons.navigation,
    'calculate': Icons.calculate,
    'games': Icons.games,
    'settings': Icons.settings,
  };

  static final Map<int, String> _codePointToName = {
    for (final entry in _nameToIcon.entries)
      entry.value.codePoint: entry.key,
  };

  static String iconToName(IconData icon) {
    return _codePointToName[icon.codePoint] ?? 'folder';
  }

  static IconData nameToIcon(String name) {
    return _nameToIcon[name] ?? Icons.folder;
  }

  /// 获取用户书签分组及书签
  static Future<Map<String, dynamic>?> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/bookmarks/groups'),
        headers: AuthService.getAuthHeaders(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final groups = data['data'] as List;
        final navList = <Map<String, dynamic>>[];
        final iconsMap = <String, List<Map<String, dynamic>>>{};
        final foldersMap = <String, Map<String, dynamic>>{};

        for (final g in groups) {
          final label = g['label'] as String;
          final iconName = g['icon'] as String? ?? 'folder';
          navList.add({
            'icon': nameToIcon(iconName),
            'label': label,
          });

          // 处理书签
          final bookmarks = g['bookmarks'] as List? ?? [];
          final folders = g['folders'] as List? ?? [];

          // 构建文件夹数据
          final folderData = <String, dynamic>{};
          for (final f in folders) {
            final folderId = f['id']?.toString() ?? '';
            final folderBookmarks = (f['bookmarks'] as List? ?? []).map<Map<String, dynamic>>((b) {
              final iconType = b['icon_type'] as String? ?? 'network';
              return {
                'id': b['id'] as int?,
                'name': b['name'] as String? ?? '',
                'url': b['url'] as String? ?? '',
                'description': b['description'] as String? ?? '',
                'type': iconType,
                if (iconType == 'network')
                  'iconUrl': b['icon_url'] as String? ?? '',
                if (iconType == 'custom')
                  'iconText': b['icon_text'] as String? ?? '',
                'color': Color(b['color'] as int? ?? 0xFF2196F3),
                'folder_id': int.parse(folderId),
              };
            }).toList();

            folderData[folderId] = {
              'id': int.parse(folderId),
              'name': f['name'] as String? ?? '未命名',
              'sort_order': f['sort_order'] as int? ?? 0,
              'bookmarks': folderBookmarks,
            };
          }
          foldersMap[label] = folderData;

          // 处理独立书签（不在文件夹中）
          iconsMap[label] = bookmarks.map<Map<String, dynamic>>((b) {
            final iconType = b['icon_type'] as String? ?? 'network';
            return {
              'id': b['id'] as int?,
              'name': b['name'] as String? ?? '',
              'url': b['url'] as String? ?? '',
              'description': b['description'] as String? ?? '',
              'type': iconType,
              if (iconType == 'network')
                'iconUrl': b['icon_url'] as String? ?? '',
              if (iconType == 'custom')
                'iconText': b['icon_text'] as String? ?? '',
              'color': Color(b['color'] as int? ?? 0xFF2196F3),
            };
          }).toList();
        }

        return {
          'navItems': navList,
          'groupIcons': iconsMap,
          'groupFolders': foldersMap,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 加载分组数据到 signals
  static Future<void> loadGroups() async {
    final data = await getGroups();
    if (data != null) {
      final items = data['navItems'] as List<Map<String, dynamic>>;
      final icons = data['groupIcons'] as Map<String, List<Map<String, dynamic>>>;
      final folders = data['groupFolders'] as Map<String, Map<String, dynamic>>;

      if (items.isNotEmpty) {
        navItems.value = items;
        groupIcons.value = icons;
        groupFolders.value = folders;
      }
    }
  }

  /// 全量保存分组+书签
  static Future<bool> saveGroups() async {
    if (AuthService.token.isEmpty) return false;
    try {
      final items = navItems.value;
      final icons = groupIcons.value;

      final groups = <Map<String, dynamic>>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final label = item['label'] as String;
        final icon = item['icon'] as IconData;
        final bookmarks = icons[label] ?? [];

        groups.add({
          'label': label,
          'icon': iconToName(icon),
          'sort_order': i,
          'bookmarks': bookmarks
              .asMap()
              .entries
              .map((e) => {
                    'name': e.value['name'] ?? '',
                    'url': e.value['url'] ?? '',
                    'icon_type': e.value['type'] ?? 'network',
                    'icon_url': e.value['iconUrl'] ?? '',
                    'icon_text': e.value['iconText'] ?? '',
                    'color': (e.value['color'] as Color?)?.value ?? 0xFF2196F3,
                    'description': e.value['description'] ?? '',
                    'sort_order': e.key,
                  })
              .toList(),
        });
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/bookmarks/groups'),
        headers: AuthService.getAuthHeaders(),
        body: jsonEncode({'groups': groups}),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
