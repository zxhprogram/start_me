import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../signals/app_signal.dart';
import '../services/github_auth_service.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsDialog({super.key, required this.onClose});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _isConnecting = false;
  String? _error;

  Future<void> _connectGitHub() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final url = await GitHubAuthService.getOAuthUrl();
    if (url == null) {
      setState(() {
        _isConnecting = false;
        _error = '获取授权链接失败';
      });
      return;
    }

    // 打开浏览器
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() {
        _isConnecting = false;
        _error = '无法打开浏览器';
      });
      return;
    }

    // 开始轮询 token
    final token = await GitHubAuthService.waitForToken();
    if (token != null) {
      // 保存 token
      await GitHubAuthService.saveToken(token);
      githubToken.value = token;

      // 获取用户信息
      final user = await GitHubAuthService.getUser(token);
      if (user != null) {
        await GitHubAuthService.saveUser(user);
        githubUser.value = user;
      }

      setState(() => _isConnecting = false);
    } else {
      setState(() {
        _isConnecting = false;
        _error = '授权超时，请重试';
      });
    }
  }

  Future<void> _disconnectGitHub() async {
    await GitHubAuthService.clearToken();
    githubToken.value = '';
    githubUser.value = {};
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          color: const Color(0xFF1E1E2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildGitHubSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text(
            '设置',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubSection() {
    return Watch((context) {
      final loggedIn = isGithubLoggedIn.value;
      final user = githubUser.value;

      return Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D3A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: Colors.white.withOpacity(0.8), size: 20),
                const SizedBox(width: 8),
                Text(
                  'GitHub 账号',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loggedIn) ...[
              // 已登录状态
              Row(
                children: [
                  // 头像
                  ClipOval(
                    child: user['avatar_url'] != null && user['avatar_url']!.isNotEmpty
                        ? Image.network(
                            user['avatar_url']!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: Colors.blue.withOpacity(0.3),
                              child: const Icon(Icons.person, color: Colors.white, size: 24),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: Colors.blue.withOpacity(0.3),
                            child: const Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name']?.isNotEmpty == true ? user['name']! : user['login'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (user['login']?.isNotEmpty == true)
                          Text(
                            '@${user['login']}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _disconnectGitHub,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '退出登录',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 未登录状态
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 12),
                  ),
                ),
              GestureDetector(
                onTap: _isConnecting ? null : _connectGitHub,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isConnecting
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isConnecting) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '等待授权中...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.login, color: Colors.white.withOpacity(0.8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '连接 GitHub',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '连接 GitHub 后可查看你 Star 的项目',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
