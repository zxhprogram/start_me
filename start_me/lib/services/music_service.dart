import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class MusicService {
  static const String _baseUrl =
      'https://mohpfgkwedpq.ap-northeast-1.clawcloudrun.com';

  /// 从热歌榜获取随机歌曲列表
  static Future<List<Map<String, dynamic>>> getRandomSongs({
    int count = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/playlist/detail?id=3778678'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['playlist']?['tracks'] as List?;
        if (tracks != null && tracks.isNotEmpty) {
          final shuffled = List.from(tracks)..shuffle(Random());
          final selected = shuffled.take(count);
          return selected.map<Map<String, dynamic>>((t) {
            final artists = (t['ar'] as List?)
                    ?.map((a) => a['name'] as String? ?? '')
                    .join(' / ') ??
                '';
            return {
              'id': t['id'] as int,
              'name': t['name'] as String? ?? '',
              'artist': artists,
              'cover': t['al']?['picUrl'] as String? ?? '',
              'duration': t['dt'] as int? ?? 0,
            };
          }).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 获取歌曲播放 URL
  static Future<String?> getSongUrl(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/song/url?id=$id'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List?;
        if (list != null && list.isNotEmpty) {
          final url = list[0]['url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取歌词
  static Future<String?> getLyric(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/lyric?id=$id'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['lrc']?['lyric'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
