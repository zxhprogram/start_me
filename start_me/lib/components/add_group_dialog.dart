import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/bookmark_service.dart';

class AddGroupDialog extends StatefulWidget {
  const AddGroupDialog({super.key});

  @override
  State<AddGroupDialog> createState() => _AddGroupDialogState();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const AddGroupDialog(),
    );
  }
}

class _AddGroupDialogState extends State<AddGroupDialog> {
  final TextEditingController _nameController = TextEditingController(
    text: '常用',
  );
  int _selectedIconIndex = 1; // 默认选中爱心图标

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final selectedIcon =
          availableIcons[_selectedIconIndex]['icon'] as IconData;

      // Add new group to navItems
      final currentItems = navItems.value;
      navItems.value = [
        ...currentItems,
        {'icon': selectedIcon, 'label': name},
      ];

      // Also create the groupIcons entry
      final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
        groupIcons.value,
      );
      currentIcons[name] = [];
      groupIcons.value = currentIcons;

      // Sync to backend
      if (isLoggedIn.value) {
        BookmarkService.saveGroups();
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D3A).withOpacity(0.98),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              '添加分组',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Icon grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableIcons.asMap().entries.map((entry) {
                final index = entry.key;
                final iconData = entry.value['icon'] as IconData;
                final isSelected = _selectedIconIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIconIndex = index;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconData,
                      color: isSelected ? Colors.white : Colors.white54,
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Name label
            const Text(
              '名称',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // Name input
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '输入分组名称',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                // Save button
                Expanded(
                  child: GestureDetector(
                    onTap: _save,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '保存',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Cancel button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '取消',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
