import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/dashboard_page.dart';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
  ],
);

class StartMeApp extends StatelessWidget {
  const StartMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Start Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Microsoft YaHei',
      ),
      routerConfig: _router,
    );
  }
}
