import 'package:flutter/material.dart';

class BookmarkShortcuts extends StatelessWidget {
  const BookmarkShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 书签按钮
        _ShortcutButton(
          icon: Icons.bookmark,
          color: Colors.orange,
          label: '书签',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        // 添加图标按钮
        _ShortcutButton(
          icon: Icons.add,
          color: Colors.white,
          label: '添加图标',
          iconColor: Colors.blue,
          onTap: () {},
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ShortcutButton({
    required this.icon,
    required this.color,
    required this.label,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
