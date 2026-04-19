import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/bookmark_service.dart';
import '../services/card_order_service.dart';
import '../services/github_auth_service.dart';
import '../signals/app_signal.dart';

class AuthDialog extends StatefulWidget {
  final VoidCallback onClose;

  const AuthDialog({super.key, required this.onClose});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool _isLogin = true; // true=login, false=register
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _error = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写用户名和密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final user = await AuthService.login(username, password);
      if (user != null && mounted) {
        await _onLoginSuccess(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写用户名和密码');
      return;
    }
    if (username.length < 2) {
      setState(() => _error = '用户名至少 2 个字符');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = '密码至少 6 个字符');
      return;
    }
    if (password != confirm) {
      setState(() => _error = '两次密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final user = await AuthService.register(username, password);
      if (user != null && mounted) {
        await _onLoginSuccess(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGitHubLogin() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 获取 OAuth URL 并在浏览器中打开
      final url = await GitHubAuthService.getOAuthUrl();
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }

      // 轮询等待 token
      final ghToken = await GitHubAuthService.waitForToken();
      if (ghToken != null && mounted) {
        // 用 GitHub token 换取应用 JWT
        final user = await AuthService.githubLogin(ghToken);
        if (user != null && mounted) {
          // 同时保存 GitHub 信息用于 GitHub 相关功能
          githubToken.value = ghToken;
          final ghUser = await GitHubAuthService.getUser(ghToken);
          if (ghUser != null) {
            githubUser.value = ghUser;
            await GitHubAuthService.saveToken(ghToken);
            await GitHubAuthService.saveUser(ghUser);
          }
          await _onLoginSuccess(user);
        }
      } else if (mounted) {
        setState(() {
          _error = 'GitHub 授权超时';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onLoginSuccess(Map<String, dynamic> user) async {
    // 更新用户信号
    appUser.value = user;
    authToken.value = AuthService.token;

    // 加载用户书签
    final bookmarkData = await BookmarkService.getGroups();
    if (bookmarkData != null) {
      final items = bookmarkData['navItems'] as List<Map<String, dynamic>>;
      final icons =
          bookmarkData['groupIcons'] as Map<String, List<Map<String, dynamic>>>;
      if (items.isNotEmpty) {
        navItems.value = items;
        groupIcons.value = icons;
        selectedNavIndex.value = 0;
      }
    }

    // 同步本地卡片顺序到服务器
    await CardOrderService.syncToServer();

    if (mounted) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 400,
          color: const Color(0xFF1E1E2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildTabs(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildForm(),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                    _buildDivider(),
                    const SizedBox(height: 16),
                    _buildGitHubButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.blue, size: 22),
          const SizedBox(width: 10),
          const Text(
            '用户登录',
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

  Widget _buildTabs() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          _buildTab('登录', _isLogin, () {
            setState(() {
              _isLogin = true;
              _error = '';
            });
          }),
          _buildTab('注册', !_isLogin, () {
            setState(() {
              _isLogin = false;
              _error = '';
            });
          }),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(color: Colors.blue, width: 2),
                )
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _usernameController,
          hint: '用户名',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _passwordController,
          hint: '密码',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        if (!_isLogin) ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _confirmPasswordController,
            hint: '确认密码',
            icon: Icons.lock_outline,
            obscure: true,
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        prefixIcon:
            Icon(icon, color: Colors.white.withOpacity(0.3), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onSubmitted: (_) => _isLogin ? _handleLogin() : _handleRegister(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (_isLogin ? _handleLogin : _handleRegister),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          disabledBackgroundColor: Colors.blue.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isLogin ? '登录' : '注册',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '或',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildGitHubButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGitHubLogin,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, color: Colors.white.withOpacity(0.7), size: 20),
            const SizedBox(width: 8),
            Text(
              'GitHub 登录',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
