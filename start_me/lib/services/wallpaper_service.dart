import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class WallpaperService {
  static const String _accessKey =
      '7rp0yM287esg4ZXhiRcfztuYOqOG1aU7hsJfzdQMV60';
  static const String _baseUrl = 'https://api.unsplash.com';

  // List of search keywords for random wallpaper
  static final List<String> _keywords = [
    'nature',
    'landscape',
    'mountain',
    'ocean',
    'forest',
    'sky',
    'sunset',
    'city',
    'architecture',
    'minimal',
    'abstract',
    'space',
    'galaxy',
    'technology',
    'programming',
  ];

  /// Get a random wallpaper from Unsplash
  static Future<String?> getRandomWallpaper() async {
    try {
      // Random keyword
      final keyword = _keywords[Random().nextInt(_keywords.length)];

      final url = Uri.parse(
        '$_baseUrl/photos/random?query=$keyword&orientation=landscape&client_id=$_accessKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Get the regular size image URL
        final imageUrl = data['urls']['regular'] as String;
        return imageUrl;
      } else {
        print('Failed to fetch wallpaper: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching wallpaper: $e');
      return null;
    }
  }

  /// Get multiple random wallpapers
  static Future<List<String>> getRandomWallpapers({int count = 10}) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/photos/random?count=$count&orientation=landscape&client_id=$_accessKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item['urls']['regular'] as String).toList();
      } else {
        print('Failed to fetch wallpapers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching wallpapers: $e');
      return [];
    }
  }
}
