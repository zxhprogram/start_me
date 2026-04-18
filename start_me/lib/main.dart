import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/memo_service.dart';
import 'services/github_auth_service.dart';
import 'services/weather_service.dart';
import 'signals/app_signal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 初始化备忘录数据
  final memos = await MemoService.fetchMemos();
  memoList.value = memos.map((m) => m.content).toList();

  // 恢复 GitHub 登录状态
  final savedToken = await GitHubAuthService.getToken();
  if (savedToken != null && savedToken.isNotEmpty) {
    githubToken.value = savedToken;
    final savedUser = await GitHubAuthService.getUser_local();
    if (savedUser != null) {
      githubUser.value = savedUser;
    }
  }

  // 恢复已订阅的热搜数据源
  final prefs = await SharedPreferences.getInstance();
  final subscribedJson = prefs.getString('subscribed_nodes');
  if (subscribedJson != null) {
    try {
      final list = jsonDecode(subscribedJson) as List;
      subscribedNodes.value = List<Map<String, dynamic>>.from(
        list.map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
  }

  // 加载天气数据
  final loc = weatherLocation.value;
  final weatherResult = await WeatherService.fetchWeather(
    lat: (loc['lat'] as num).toDouble(),
    lon: (loc['lon'] as num).toDouble(),
    location: loc['name'] as String,
  );
  if (weatherResult != null) {
    fullWeatherData.value = weatherResult;
  }

  runApp(const StartMeApp());
}
