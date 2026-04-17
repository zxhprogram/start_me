import 'dart:convert';
import 'package:http/http.dart' as http;

class TrendingRepo {
  final String name;
  final String description;
  final String language;
  final int stars;
  final int starsPeriod;
  final String url;

  TrendingRepo({
    required this.name,
    required this.description,
    required this.language,
    required this.stars,
    required this.starsPeriod,
    required this.url,
  });

  factory TrendingRepo.fromJson(Map<String, dynamic> json) {
    return TrendingRepo(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      language: json['language'] ?? '',
      stars: json['stars'] ?? 0,
      starsPeriod: json['starsPeriod'] ?? 0,
      url: json['url'] ?? '',
    );
  }
}

class GitHubService {
  static const String _baseUrl = 'http://localhost:8080/api';

  /// 获取 GitHub Trending 数据
  static Future<List<TrendingRepo>> fetchTrending(String period) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/github/trending?period=$period'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => TrendingRepo.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching GitHub trending: $e');
      return [];
    }
  }

  /// 获取 GitHub 仓库 README
  static Future<String?> fetchRepoReadme(String repoName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/github/readme?repo=$repoName'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as String;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching repo readme: $e');
      return null;
    }
  }
}
