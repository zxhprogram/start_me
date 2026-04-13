import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import 'add_icon_dialog.dart';

class GroupIconsGrid extends StatefulWidget {
  final String groupLabel;

  const GroupIconsGrid({super.key, required this.groupLabel});

  @override
  State<GroupIconsGrid> createState() => _GroupIconsGridState();
}

class _GroupIconsGridState extends State<GroupIconsGrid> {
  int? _draggingIndex;

  void _showAddIconDialog(BuildContext context) {
    AddIconDialog.show(context, widget.groupLabel);
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final icons = groupIcons.value[widget.groupLabel] ?? [];

      return Container(
        width: double.infinity,
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            ...icons.asMap().entries.map((entry) {
              final index = entry.key;
              final iconData = entry.value;
              final isDragging = _draggingIndex == index;

              return Draggable<int>(
                data: index,
                maxSimultaneousDrags: 1,
                onDragStarted: () {
                  setState(() {
                    _draggingIndex = index;
                  });
                },
                onDragEnd: (details) {
                  setState(() {
                    _draggingIndex = null;
                  });
                },
                onDraggableCanceled: (_, __) {
                  setState(() {
                    _draggingIndex = null;
                  });
                },
                feedback: _buildFeedback(iconData),
                childWhenDragging: _buildPlaceholder(),
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) {
                    return details.data != index;
                  },
                  onAcceptWithDetails: (details) {
                    final fromIndex = details.data;
                    if (fromIndex != index) {
                      reorderGroupIcons(widget.groupLabel, fromIndex, index);
                    }
                    setState(() {
                      _draggingIndex = null;
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isTarget =
                        candidateData.isNotEmpty && _draggingIndex != index;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      transform: isTarget
                          ? Matrix4.translationValues(0, 8, 0)
                          : Matrix4.identity(),
                      child: _buildIconItem(
                        iconData: iconData,
                        isDragging: isDragging,
                        isTarget: isTarget,
                      ),
                    );
                  },
                ),
              );
            }),
            _buildAddButton(context),
          ],
        ),
      );
    });
  }

  Widget _buildFeedback(Map<String, dynamic> iconData) {
    return Transform.scale(
      scale: 1.1,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildIconContent(iconData),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 72,
      height: 72 + 24,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  Widget _buildIconItem({
    required Map<String, dynamic> iconData,
    bool isDragging = false,
    bool isTarget = false,
  }) {
    final name = iconData['name'] as String? ?? 'Unknown';
    final color = iconData['color'] is Color
        ? iconData['color'] as Color
        : Colors.blue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isDragging ? Colors.white.withOpacity(0.8) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isTarget
                    ? color.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
                blurRadius: isTarget ? 12 : 8,
                spreadRadius: isTarget ? 2 : 0,
                offset: const Offset(0, 4),
              ),
            ],
            border: isTarget ? Border.all(color: color, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildIconContent(iconData),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: TextStyle(
              color: isTarget ? color : Colors.white,
              fontSize: 12,
              fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildIconContent(Map<String, dynamic> iconData) {
    final type = iconData['type'] as String? ?? 'custom';

    if (type == 'network') {
      // Network icon - show favicon image
      final iconUrl = iconData['iconUrl'] as String?;
      if (iconUrl != null && iconUrl.isNotEmpty) {
        return Image.network(
          iconUrl,
          width: 72,
          height: 72,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to custom icon
            return _buildCustomIcon(iconData);
          },
        );
      }
    }

    // Custom icon or fallback
    return _buildCustomIcon(iconData);
  }

  Widget _buildCustomIcon(Map<String, dynamic> iconData) {
    final color = iconData['color'] is Color
        ? iconData['color'] as Color
        : Colors.blue;
    final iconText =
        iconData['iconText'] as String? ??
        (iconData['name'] as String? ?? '?').substring(0, 1).toUpperCase();

    return Container(
      width: 72,
      height: 72,
      color: color,
      child: Center(
        child: Text(
          iconText.substring(0, iconText.length.clamp(1, 2)),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddIconDialog(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add, color: Colors.blue, size: 36),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 80,
            child: Text(
              '添加图标',
              style: TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
