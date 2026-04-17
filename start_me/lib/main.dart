import 'package:flutter/material.dart';
import 'app.dart';
import 'services/memo_service.dart';
import 'services/github_auth_service.dart';
import 'signals/app_signal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const StartMeApp());
}
