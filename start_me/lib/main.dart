import 'package:flutter/material.dart';
import 'app.dart';
import 'services/memo_service.dart';
import 'signals/app_signal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化备忘录数据
  final memos = await MemoService.fetchMemos();
  memoList.value = memos.map((m) => m.content).toList();

  runApp(const StartMeApp());
}
