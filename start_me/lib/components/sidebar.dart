import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/auth_service.dart';
import '../services/github_auth_service.dart';
import 'add_group_dialog.dart';
import 'edit_group_dialog.dart';
import 'remove_group_dialog.dart';
import 'settings_dialog.dart';
import 'auth_dialog.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  void _showAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AuthDialog(
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showUserMenu(Offset position) {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final user = appUser.value;
    final username = user?['username'] as String? ?? '';

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<int>(
          enabled: false,
          child: Text(
            username,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.redAccent),
              SizedBox(width: 12),
              Text('退出登录', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      elevation: 8,
      color: const Color(0xFF2D2D3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).then((value) {
      if (value == 1) {
        _logout();
      }
    });
  }

  void _logout() async {
    await AuthService.clearToken();
    await GitHubAuthService.clearToken();
    appUser.value = null;
    authToken.value = '';
    githubToken.value = '';
    githubUser.value = {};
    // 恢复默认书签
    navItems.value = [
      {'icon': Icons.home, 'label': '主页'},
      {'icon': Icons.code, 'label': '程序员'},
      {'icon': Icons.design_services, 'label': '设计'},
      {'icon': Icons.shopping_bag, 'label': '产品'},
      {'icon': Icons.work, 'label': 'work'},
      {'icon': Icons.book, 'label': 'study'},
      {'icon': Icons.folder, 'label': '文档'},
      {'icon': Icons.build, 'label': '工具'},
      {'icon': Icons.navigation, 'label': '导航'},
      {'icon': Icons.calculate, 'label': '数学'},
      {'icon': Icons.games, 'label': '摸鱼'},
    ];
    groupIcons.value = {
      '主页': [],
      '程序员': [],
      '设计': [],
      '产品': [],
      'work': [],
      'study': [],
      '文档': [],
      '工具': [],
      '导航': [],
      '数学': [],
      '摸鱼': [],
    };
    selectedNavIndex.value = 0;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SettingsDialog(
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showAddGroupDialog() {
    AddGroupDialog.show(context);
  }

  void _showEditGroupDialog(int index) {
    EditGroupDialog.show(context, index);
  }

  void _showRemoveGroupDialog(int index) {
    RemoveGroupDialog.show(context, index);
  }

  void _showContextMenu(BuildContext context, int index, Offset position) {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.white70),
              SizedBox(width: 12),
              Text('编辑分组', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        if (index != 0)
          PopupMenuItem<int>(
            value: 1,
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  '移除分组',
                  style: TextStyle(color: Colors.red.withOpacity(0.9)),
                ),
              ],
            ),
          ),
      ],
      elevation: 8,
      color: const Color(0xFF2D2D3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).then((value) {
      if (value == 0) {
        _showEditGroupDialog(index);
      } else if (value == 1) {
        _showRemoveGroupDialog(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      color: const Color(0xFF1A1A1A).withOpacity(0.9),
      child: Column(
        children: [
          // User avatar
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            child: Watch((context) {
              final user = appUser.value;
              final avatarUrl = user?['avatar_url'] as String? ?? '';
              final loggedIn = isLoggedIn.value;
              return GestureDetector(
                onTap: () {
                  if (!loggedIn) {
                    _showAuthDialog();
                  }
                },
                onSecondaryTapUp: loggedIn
                    ? (details) => _showUserMenu(details.globalPosition)
                    : null,
                onLongPress: loggedIn
                    ? () {
                        final box = context.findRenderObject() as RenderBox;
                        final pos = box.localToGlobal(
                            Offset(box.size.width, box.size.height / 2));
                        _showUserMenu(pos);
                      }
                    : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.3),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, color: Colors.white, size: 28),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 28),
                ),
              );
            }),
          ),

          // Online indicator
          Watch((context) {
            final loggedIn = isLoggedIn.value;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: loggedIn ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            );
          }),

          const SizedBox(height: 24),

          // Navigation items
          Expanded(
            child: Watch((context) {
              // Access both signals to ensure proper dependency tracking
              final items = navItems.value;
              final selectedIndex = selectedNavIndex.value;

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = selectedIndex == index;

                  return GestureDetector(
                    onSecondaryTapUp: (details) {
                      _showContextMenu(context, index, details.globalPosition);
                    },
                    child: _NavItem(
                      icon: item['icon'] as IconData,
                      label: item['label'] as String,
                      isSelected: isSelected,
                      onTap: () => selectedNavIndex.value = index,
                    ),
                  );
                },
              );
            }),
          ),

          // Bottom actions
          Column(
            children: [
              _NavItem(
                icon: Icons.add,
                label: '',
                isSelected: false,
                onTap: _showAddGroupDialog,
              ),
              _NavItem(
                icon: Icons.settings,
                label: '',
                isSelected: false,
                onTap: _showSettingsDialog,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: label.isEmpty ? 48 : 64,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Left blue indicator
            if (isSelected)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white54,
                    size: 24,
                  ),
                  if (label.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
