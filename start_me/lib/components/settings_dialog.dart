import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../signals/app_signal.dart';
import '../services/github_auth_service.dart';
import '../services/email_service.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsDialog({super.key, required this.onClose});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _isConnecting = false;
  String? _error;

  // Email config state
  final _emailHostController = TextEditingController();
  final _emailPortController = TextEditingController(text: '995');
  final _emailUsernameController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  bool _emailUseTls = true;
  bool _emailSaving = false;
  String? _emailError;

  @override
  void dispose() {
    _emailHostController.dispose();
    _emailPortController.dispose();
    _emailUsernameController.dispose();
    _emailPasswordController.dispose();
    super.dispose();
  }

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildGitHubSection(),
                _buildEmailSection(),
                const SizedBox(height: 20),
              ],
            ),
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

  Widget _buildEmailSection() {
    return Watch((context) {
      final loggedIn = isLoggedIn.value;
      if (!loggedIn) return const SizedBox.shrink();

      final configured = emailConfigured.value;

      return Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.8), size: 20),
                const SizedBox(width: 8),
                Text(
                  '邮箱配置 (POP3)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (configured) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '邮箱已配置',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await EmailService.deleteConfig();
                      emailConfigured.value = false;
                      emailList.value = [];
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '断开连接',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildEmailField('POP3 服务器', _emailHostController, 'pop.example.com'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildEmailField('端口', _emailPortController, '995'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _emailUseTls,
                            onChanged: (v) => setState(() => _emailUseTls = v ?? true),
                            activeColor: Colors.blue,
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('TLS', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildEmailField('邮箱账号', _emailUsernameController, 'user@example.com'),
              const SizedBox(height: 10),
              _buildEmailField('密码/授权码', _emailPasswordController, '密码或授权码', obscure: true),
              if (_emailError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _emailError!,
                  style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _emailSaving ? null : _saveEmailConfig,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _emailSaving
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _emailSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '保存并测试连接',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildEmailField(String label, TextEditingController controller, String hint, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _saveEmailConfig() async {
    final host = _emailHostController.text.trim();
    final portStr = _emailPortController.text.trim();
    final username = _emailUsernameController.text.trim();
    final password = _emailPasswordController.text;

    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _emailError = '请填写所有字段');
      return;
    }

    final port = int.tryParse(portStr) ?? 995;

    setState(() {
      _emailSaving = true;
      _emailError = null;
    });

    try {
      await EmailService.saveConfig(
        host: host,
        port: port,
        username: username,
        password: password,
        useTls: _emailUseTls,
      );
      if (mounted) {
        emailConfigured.value = true;
        setState(() => _emailSaving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = e.toString().replaceFirst('Exception: ', '');
          _emailSaving = false;
        });
      }
    }
  }
}
