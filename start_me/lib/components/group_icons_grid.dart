import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/bookmark_folder_service.dart';
import '../services/bookmark_service.dart';
import 'add_icon_dialog.dart';

class GroupIconsGrid extends StatefulWidget {
  final String groupLabel;

  const GroupIconsGrid({super.key, required this.groupLabel});

  @override
  State<GroupIconsGrid> createState() => _GroupIconsGridState();
}

class _GroupIconsGridState extends State<GroupIconsGrid> {
  int? _draggingIndex;
  Timer? _mergeTimer;
  int? _hoveredIndex;
  bool _isMerging = false;

  @override
  void dispose() {
    _mergeTimer?.cancel();
    super.dispose();
  }

  void _showAddIconDialog(BuildContext context) {
    AddIconDialog.show(context, widget.groupLabel);
  }

  /// 开始合并计时
  void _startMergeTimer(int fromIndex, int toIndex) {
    _mergeTimer?.cancel();
    setState(() {
      _hoveredIndex = toIndex;
    });

    _mergeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _hoveredIndex == toIndex && !_isMerging) {
        _performMerge(fromIndex, toIndex);
      }
    });
  }

  /// 取消合并计时
  void _cancelMergeTimer() {
    _mergeTimer?.cancel();
    setState(() {
      _hoveredIndex = null;
    });
  }

  /// 执行合并操作
  Future<void> _performMerge(int fromIndex, int toIndex) async {
    if (_isMerging) return;
    setState(() => _isMerging = true);

    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
      groupIcons.value,
    );

    final icons = [...currentIcons[widget.groupLabel] ?? []];
    if (fromIndex >= icons.length || toIndex >= icons.length) {
      setState(() => _isMerging = false);
      return;
    }

    final fromBookmark = icons[fromIndex];
    final toBookmark = icons[toIndex];

    final fromIsFolder = fromBookmark['type'] == 'folder';
    final toIsFolder = toBookmark['type'] == 'folder';

    if (fromIsFolder || toIsFolder) {
      // 拖入已有文件夹：将书签添加到文件夹
      final folderSentinel = fromIsFolder ? fromBookmark : toBookmark;
      final bookmark = fromIsFolder ? toBookmark : fromBookmark;
      final bookmarkIndex = fromIsFolder ? toIndex : fromIndex;
      final folderId = folderSentinel['folder_id'] as int;
      _addBookmarkToFolder(folderId, bookmark, bookmarkIndex);
    } else {
      final fromId = fromBookmark['id'] as int?;
      final toId = toBookmark['id'] as int?;
      if (fromId == null || toId == null) {
        await _createLocalFolder(fromBookmark, toBookmark, fromIndex, toIndex);
      } else {
        await _createServerFolder(fromId, toId, fromIndex, toIndex);
      }
    }

    if (mounted) {
      setState(() {
        _isMerging = false;
        _hoveredIndex = null;
      });
    }
  }

  /// 将书签添加到已有文件夹
  void _addBookmarkToFolder(int folderId, Map<String, dynamic> bookmark, int bookmarkIndex) {
    final currentFolders = Map<String, Map<String, dynamic>>.from(groupFolders.value);
    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(groupIcons.value);

    final folders = Map<String, dynamic>.from(currentFolders[widget.groupLabel] ?? {});
    final folderData = folders[folderId.toString()] as Map<String, dynamic>?;
    if (folderData == null) return;

    final bookmarks = [...(folderData['bookmarks'] as List<dynamic>? ?? [])];
    bookmarks.add(Map<String, dynamic>.from(bookmark));
    folderData['bookmarks'] = bookmarks;
    folders[folderId.toString()] = folderData;
    currentFolders[widget.groupLabel] = folders;

    final icons = [...currentIcons[widget.groupLabel] ?? []];
    icons.removeAt(bookmarkIndex);
    currentIcons[widget.groupLabel] = List<Map<String, dynamic>>.from(icons);

    groupFolders.value = currentFolders;
    groupIcons.value = currentIcons;
    _syncBookmarks();
  }

  /// 创建本地文件夹（未登录状态）
  Future<void> _createLocalFolder(
    Map<String, dynamic> bookmark1,
    Map<String, dynamic> bookmark2,
    int index1,
    int index2,
  ) async {
    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
      groupIcons.value,
    );
    final currentFolders = Map<String, Map<String, dynamic>>.from(
      groupFolders.value,
    );

    final icons = [...currentIcons[widget.groupLabel] ?? []];
    final folders =
        Map<String, dynamic>.from(currentFolders[widget.groupLabel] ?? {});

    // 生成临时文件夹ID（负数表示本地文件夹）
    final folderId = -DateTime.now().millisecondsSinceEpoch;

    // 创建文件夹
    final folder = {
      'id': folderId,
      'name': '未命名',
      'bookmarks': [Map<String, dynamic>.from(bookmark1), Map<String, dynamic>.from(bookmark2)],
      'sort_order': icons.length,
    };

    folders[folderId.toString()] = folder;

    // 移除原书签
    final minIndex = index1 < index2 ? index1 : index2;
    final maxIndex = index1 > index2 ? index1 : index2;
    icons.removeAt(maxIndex);
    icons.removeAt(minIndex);

    // 在原来位置插入文件夹占位符
    icons.insert(minIndex, {
      'type': 'folder',
      'folder_id': folderId,
      'name': '未命名',
    });

    currentIcons[widget.groupLabel] = List<Map<String, dynamic>>.from(icons);
    currentFolders[widget.groupLabel] = folders;

    groupIcons.value = currentIcons;
    groupFolders.value = currentFolders;

    _syncBookmarks();
  }

  /// 创建服务器文件夹（已登录状态）
  Future<void> _createServerFolder(
    int bookmarkId1,
    int bookmarkId2,
    int index1,
    int index2,
  ) async {
    // 简化处理：本地创建，同步到服务器
    await _createLocalFolder(
      {'id': bookmarkId1, 'name': 'Bookmark 1', 'type': 'network'},
      {'id': bookmarkId2, 'name': 'Bookmark 2', 'type': 'network'},
      index1,
      index2,
    );
  }

  void _syncBookmarks() {
    if (isLoggedIn.value) {
      BookmarkService.saveGroups();
    }
  }

  /// 显示文件夹右键菜单
  void _showFolderContextMenu(
    BuildContext context,
    int folderId,
    String currentName,
    Offset position,
  ) {
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
              Text('重命名', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                '解散文件夹',
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
        _showRenameDialog(folderId, currentName);
      } else if (value == 1) {
        _dissolveFolder(folderId);
      }
    });
  }

  /// 显示文件夹详情弹窗
  void _showFolderDetailDialog(int folderId, String folderName) {
    final currentFolders = Map<String, Map<String, dynamic>>.from(
      groupFolders.value,
    );
    final folders = currentFolders[widget.groupLabel] ?? {};
    final folderData = folders[folderId.toString()] as Map<String, dynamic>?;
    if (folderData == null) return;

    showDialog(
      context: context,
      builder: (context) => _FolderDetailDialog(
        folderId: folderId,
        folderName: folderName,
        groupLabel: widget.groupLabel,
        folderData: folderData,
        onRename: (newName) => _renameFolder(folderId, newName),
        onDissolve: () => _dissolveFolder(folderId),
        onBookmarkRemoved: (bookmarkId) => _onBookmarkRemovedFromFolder(folderId, bookmarkId),
        onBookmarksReordered: (bookmarks) => _onBookmarksReordered(folderId, bookmarks),
      ),
    );
  }

  /// 书签从文件夹移出后的处理
  void _onBookmarkRemovedFromFolder(int folderId, int bookmarkId) {
    final currentFolders = Map<String, Map<String, dynamic>>.from(
      groupFolders.value,
    );
    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
      groupIcons.value,
    );
    
    final folders = currentFolders[widget.groupLabel] ?? {};
    final folderData = folders[folderId.toString()] as Map<String, dynamic>?;
    if (folderData == null) return;

    final bookmarks = (folderData['bookmarks'] as List<dynamic>?)?.toList() ?? [];
    
    // 找到并移除书签
    int removedIndex = -1;
    for (int i = 0; i < bookmarks.length; i++) {
      final bookmark = bookmarks[i] as Map<String, dynamic>;
      if (bookmark['id'] == bookmarkId ||
          (bookmark['id'] == null && i == bookmarkId)) {
        removedIndex = i;
        break;
      }
    }
    
    if (removedIndex >= 0) {
      final removedBookmark = Map<String, dynamic>.from(bookmarks[removedIndex]);
      bookmarks.removeAt(removedIndex);
      
      // 检查文件夹是否为空
      if (bookmarks.isEmpty) {
        // 自动删除空文件夹
        _dissolveFolder(folderId);
      } else {
        // 更新文件夹数据
        folderData['bookmarks'] = bookmarks;
        folders[folderId.toString()] = folderData;
        currentFolders[widget.groupLabel] = folders;
        groupFolders.value = currentFolders;
        
        // 将书签移出到分组
        final icons = [...currentIcons[widget.groupLabel] ?? []];
        int folderIndex = -1;
        for (int i = 0; i < icons.length; i++) {
          if (icons[i]['folder_id'] == folderId) {
            folderIndex = i;
            break;
          }
        }
        
        if (folderIndex >= 0) {
          // 在文件夹后面添加移出的书签
          icons.insert(folderIndex + 1, removedBookmark);
          currentIcons[widget.groupLabel] = List<Map<String, dynamic>>.from(icons);
          groupIcons.value = currentIcons;
        }
      }
    }
    
    _syncBookmarks();
  }

  /// 书签排序后的处理
  void _onBookmarksReordered(int folderId, List<Map<String, dynamic>> newBookmarks) {
    final currentFolders = Map<String, Map<String, dynamic>>.from(
      groupFolders.value,
    );
    final folders = currentFolders[widget.groupLabel] ?? {};
    final folderData = folders[folderId.toString()] as Map<String, dynamic>?;
    if (folderData == null) return;

    folderData['bookmarks'] = newBookmarks;
    folders[folderId.toString()] = folderData;
    currentFolders[widget.groupLabel] = folders;
    groupFolders.value = currentFolders;
    
    _syncBookmarks();
  }

  /// 显示重命名对话框
  void _showRenameDialog(int folderId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 360,
            color: const Color(0xFF1E1E2E),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '重命名文件夹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '文件夹名称',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          await _renameFolder(folderId, newName);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 重命名文件夹
  Future<void> _renameFolder(int folderId, String newName) async {
    if (folderId < 0) {
      // 本地文件夹
      final currentFolders = Map<String, Map<String, dynamic>>.from(
        groupFolders.value,
      );
      final folders =
          Map<String, dynamic>.from(currentFolders[widget.groupLabel] ?? {});

      if (folders.containsKey(folderId.toString())) {
        final folder =
            Map<String, dynamic>.from(folders[folderId.toString()]);
        folder['name'] = newName;
        folders[folderId.toString()] = folder;
        currentFolders[widget.groupLabel] = folders;
        groupFolders.value = currentFolders;

        // 更新显示
        _updateFolderDisplay(folderId, newName);
      }
    } else {
      // 服务器文件夹
      final success = await BookmarkFolderService.renameFolder(folderId, newName);
      if (success) {
        await BookmarkService.loadGroups();
      }
    }
    _syncBookmarks();
  }

  /// 更新文件夹显示
  void _updateFolderDisplay(int folderId, String newName) {
    // 更新 groupIcons 信号
    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
      groupIcons.value,
    );
    final icons = currentIcons[widget.groupLabel] ?? [];
    final updatedIcons = <Map<String, dynamic>>[];

    for (var i = 0; i < icons.length; i++) {
      final iconItem = icons[i];
      if (iconItem['folder_id'] == folderId) {
        updatedIcons.add({
          'type': 'folder',
          'folder_id': folderId,
          'name': newName,
        });
      } else {
        updatedIcons.add(Map<String, dynamic>.from(iconItem));
      }
    }

    currentIcons[widget.groupLabel] = updatedIcons;
    groupIcons.value = currentIcons;

    // 更新 groupFolders 信号
    final currentFolders = Map<String, Map<String, dynamic>>.from(
      groupFolders.value,
    );
    final folders = currentFolders[widget.groupLabel];
    if (folders != null && folders.containsKey(folderId.toString())) {
      final folderData = Map<String, dynamic>.from(folders[folderId.toString()]!);
      folderData['name'] = newName;
      folders[folderId.toString()] = folderData;
      currentFolders[widget.groupLabel] = folders;
      groupFolders.value = currentFolders;
    }
  }

  /// 解散文件夹
  Future<void> _dissolveFolder(int folderId) async {
    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
      groupIcons.value,
    );
    final currentFolders = Map<String, Map<String, dynamic>>.from(
      groupFolders.value,
    );

    final icons = [...currentIcons[widget.groupLabel] ?? []];
    final folders =
        Map<String, dynamic>.from(currentFolders[widget.groupLabel] ?? {});

    if (folders.containsKey(folderId.toString())) {
      final folder = folders[folderId.toString()] as Map<String, dynamic>;
      final bookmarks = folder['bookmarks'] as List<dynamic>? ?? [];

      // 找到文件夹在图标列表中的位置
      int folderIndex = -1;
      for (int i = 0; i < icons.length; i++) {
        if (icons[i]['folder_id'] == folderId) {
          folderIndex = i;
          break;
        }
      }

      if (folderIndex >= 0) {
        // 移除文件夹占位符
        icons.removeAt(folderIndex);

        // 将书签放回原位置
        for (int i = bookmarks.length - 1; i >= 0; i--) {
          final bookmark = bookmarks[i] as Map<dynamic, dynamic>;
          icons.insert(folderIndex, Map<String, dynamic>.from(bookmark));
        }
      }

      // 删除文件夹
      folders.remove(folderId.toString());
    }

    currentIcons[widget.groupLabel] = List<Map<String, dynamic>>.from(icons);
    currentFolders[widget.groupLabel] = folders;

    groupIcons.value = currentIcons;
    groupFolders.value = currentFolders;

    _syncBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final icons = groupIcons.value[widget.groupLabel] ?? [];
      final folders = groupFolders.value[widget.groupLabel] ?? {};

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
              final isFolder = iconData['type'] == 'folder';
              final folderId = iconData['folder_id'];

              if (isFolder && folderId != null) {
                // 渲染文件夹
                final folderData =
                    folders[folderId.toString()] as Map<String, dynamic>?;
                if (folderData != null) {
                  return _buildFolderItem(
                    folderData: folderData,
                    folderId: folderId,
                    index: index,
                    isDragging: isDragging,
                  );
                }
                return const SizedBox.shrink();
              }

              // 渲染普通书签
              return _buildBookmarkItem(
                iconData: iconData,
                index: index,
                isDragging: isDragging,
                icons: icons,
              );
            }),
            _buildAddButton(context),
          ],
        ),
      );
    });
  }

  /// 构建文件夹项（显示4个缩略图）
  Widget _buildFolderItem({
    required Map<String, dynamic> folderData,
    required int folderId,
    required int index,
    required bool isDragging,
  }) {
    final bookmarks = folderData['bookmarks'] as List<dynamic>? ?? [];
    final folderName = folderData['name'] as String? ?? '未命名';

    return GestureDetector(
      onTap: () => _showFolderDetailDialog(folderId, folderName),
      onSecondaryTapUp: (details) {
        _showFolderContextMenu(context, folderId, folderName, details.globalPosition);
      },
      child: Draggable<int>(
        data: index,
        maxSimultaneousDrags: 1,
        onDragStarted: () {
          setState(() => _draggingIndex = index);
        },
        onDragEnd: (details) {
          setState(() => _draggingIndex = null);
          _cancelMergeTimer();
        },
        onDraggableCanceled: (_, __) {
          setState(() => _draggingIndex = null);
          _cancelMergeTimer();
        },
        feedback: _buildFolderFeedback(folderName, bookmarks.length),
        childWhenDragging: _buildPlaceholder(),
        child: DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            final willAccept = details.data != index && _draggingIndex != null;
            if (willAccept) {
              _startMergeTimer(details.data, index);
            }
            return willAccept;
          },
          onLeave: (_) => _cancelMergeTimer(),
          onAcceptWithDetails: (details) {
            _cancelMergeTimer();
            // 可以在这里实现将书签拖入文件夹的功能
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            final isTarget = isHovering && _hoveredIndex == index;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: isTarget
                  ? Matrix4.translationValues(0, 8, 0)
                  : Matrix4.identity(),
              child: SizedBox(
                width: 72,
                height: 96,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDragging
                            ? Colors.white.withOpacity(0.8)
                            : Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isTarget
                                ? Colors.blue.withOpacity(0.5)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: isTarget ? 12 : 8,
                            spreadRadius: isTarget ? 2 : 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isTarget
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildFolderThumbnails(bookmarks),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      height: 16,
                      child: Text(
                        folderName,
                        style: TextStyle(
                          color: isTarget ? Colors.blue : Colors.white,
                          fontSize: 11,
                          fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建文件夹缩略图（最多显示4个）
  /// 布局规则：
  /// - 1个：居中显示
  /// - 2个：一行2个并排
  /// - 3个：2行（2+1，第3个在第二行居中）
  /// - 4个：2x2网格
  Widget _buildFolderThumbnails(List<dynamic> bookmarks) {
    // 获取前4个书签的缩略图
    final displayBookmarks = bookmarks.take(4).toList();

    if (displayBookmarks.isEmpty) {
      return const Center(
        child: Icon(
          Icons.folder,
          color: Colors.white,
          size: 36,
        ),
      );
    }

    final count = displayBookmarks.length;
    
    // 计算缩略图大小
    final thumbnailSize = 28.0;
    final spacing = 4.0;

    if (count == 1) {
      // 1个：居中显示
      return Center(
        child: _buildThumbnailIcon(displayBookmarks[0] as Map<String, dynamic>, thumbnailSize),
      );
    } else if (count == 2) {
      // 2个：一行2个并排
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildThumbnailIcon(displayBookmarks[0] as Map<String, dynamic>, thumbnailSize),
            SizedBox(width: spacing),
            _buildThumbnailIcon(displayBookmarks[1] as Map<String, dynamic>, thumbnailSize),
          ],
        ),
      );
    } else if (count == 3) {
      // 3个：2行（2+1，第3个在第二行居中）
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildThumbnailIcon(displayBookmarks[0] as Map<String, dynamic>, thumbnailSize),
                SizedBox(width: spacing),
                _buildThumbnailIcon(displayBookmarks[1] as Map<String, dynamic>, thumbnailSize),
              ],
            ),
            SizedBox(height: spacing),
            _buildThumbnailIcon(displayBookmarks[2] as Map<String, dynamic>, thumbnailSize),
          ],
        ),
      );
    } else {
      // 4个：2x2网格
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildThumbnailIcon(displayBookmarks[0] as Map<String, dynamic>, thumbnailSize),
                SizedBox(width: spacing),
                _buildThumbnailIcon(displayBookmarks[1] as Map<String, dynamic>, thumbnailSize),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildThumbnailIcon(displayBookmarks[2] as Map<String, dynamic>, thumbnailSize),
                SizedBox(width: spacing),
                _buildThumbnailIcon(displayBookmarks[3] as Map<String, dynamic>, thumbnailSize),
              ],
            ),
          ],
        ),
      );
    }
  }

  /// 构建缩略图（可变大小）
  Widget _buildThumbnailIcon(Map<String, dynamic> iconData, double size) {
    final type = iconData['type'] as String? ?? 'custom';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildThumbnailContent(iconData, size),
      ),
    );
  }

  /// 构建缩略图内容
  Widget _buildThumbnailContent(Map<String, dynamic> iconData, double size) {
    final type = iconData['type'] as String? ?? 'custom';

    if (type == 'network') {
      final iconUrl = iconData['iconUrl'] as String?;
      if (iconUrl != null && iconUrl.isNotEmpty) {
        return Image.network(
          iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 加载失败显示默认图标
            return _buildThumbnailFallback(iconData, size);
          },
        );
      }
    }

    return _buildThumbnailFallback(iconData, size);
  }

  /// 构建缩略图默认显示
  Widget _buildThumbnailFallback(Map<String, dynamic> iconData, double size) {
    final color = iconData['color'] is Color
        ? iconData['color'] as Color
        : Colors.blue;
    final iconText = iconData['iconText'] as String? ??
        (iconData['name'] as String? ?? '?').substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      color: color,
      child: Center(
        child: Text(
          iconText.substring(0, iconText.length.clamp(1, 1)),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 构建书签项
  Widget _buildBookmarkItem({
    required Map<String, dynamic> iconData,
    required int index,
    required bool isDragging,
    required List<Map<String, dynamic>> icons,
  }) {
    return Draggable<int>(
      data: index,
      maxSimultaneousDrags: 1,
      onDragStarted: () {
        setState(() => _draggingIndex = index);
      },
      onDragEnd: (details) {
        setState(() => _draggingIndex = null);
        _cancelMergeTimer();
      },
      onDraggableCanceled: (_, __) {
        setState(() => _draggingIndex = null);
        _cancelMergeTimer();
      },
      feedback: _buildFeedback(iconData),
      childWhenDragging: _buildPlaceholder(),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          final willAccept = details.data != index && _draggingIndex != null;
          if (willAccept) {
            _startMergeTimer(details.data, index);
          }
          return willAccept;
        },
        onLeave: (_) => _cancelMergeTimer(),
        onAcceptWithDetails: (details) {
          _cancelMergeTimer();
          final fromIndex = details.data;
          if (fromIndex != index) {
            reorderGroupIcons(widget.groupLabel, fromIndex, index);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          final isTarget = isHovering && _hoveredIndex == index;

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
  }

  Widget _buildFolderFeedback(String name, int count) {
    return Transform.scale(
      scale: 1.1,
      child: Container(
        width: 72,
        height: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
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
              child: const Center(
                child: Icon(
                  Icons.folder,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 80,
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
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
      height: 96,
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
    final iconText = iconData['iconText'] as String? ??
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

/// 文件夹详情弹窗
class _FolderDetailDialog extends StatefulWidget {
  final int folderId;
  final String folderName;
  final String groupLabel;
  final Map<String, dynamic> folderData;
  final Function(String) onRename;
  final Function() onDissolve;
  final Function(int) onBookmarkRemoved;
  final Function(List<Map<String, dynamic>>) onBookmarksReordered;

  const _FolderDetailDialog({
    required this.folderId,
    required this.folderName,
    required this.groupLabel,
    required this.folderData,
    required this.onRename,
    required this.onDissolve,
    required this.onBookmarkRemoved,
    required this.onBookmarksReordered,
  });

  @override
  State<_FolderDetailDialog> createState() => _FolderDetailDialogState();
}

class _FolderDetailDialogState extends State<_FolderDetailDialog> {
  late String _folderName;
  late List<Map<String, dynamic>> _bookmarks;
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _folderName = widget.folderName;
    final bookmarks = widget.folderData['bookmarks'] as List<dynamic>? ?? [];
    _bookmarks = bookmarks.map((b) => Map<String, dynamic>.from(b as Map)).toList();
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _folderName);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 360,
            color: const Color(0xFF1E1E2E),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '重命名文件夹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '文件夹名称',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          await widget.onRename(newName);
                          setState(() => _folderName = newName);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建书签网格
  Widget _buildBookmarkGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算每行可以显示的书签数量
        final availableWidth = constraints.maxWidth - 32; // 减去padding
        final itemWidth = 72 + 16; // 图标宽度 + 间距
        final crossAxisCount = (availableWidth / itemWidth).floor().clamp(1, 8);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.start,
          children: _bookmarks.asMap().entries.map((entry) {
            final index = entry.key;
            final bookmark = entry.value;
            return _FolderBookmarkGridItem(
              key: ValueKey(bookmark['id'] ?? index),
              bookmark: bookmark,
              index: index,
              onRemove: () => _removeBookmark(index),
              onDragStarted: () => setState(() => _draggingIndex = index),
              onDragEnd: () => setState(() => _draggingIndex = null),
              onAccept: (fromIndex) => _reorderBookmarks(fromIndex, index),
              isDragging: _draggingIndex == index,
            );
          }).toList(),
        );
      },
    );
  }

  void _reorderBookmarks(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    setState(() {
      final bookmark = _bookmarks.removeAt(oldIndex);
      final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      _bookmarks.insert(adjustedIndex, bookmark);
    });

    widget.onBookmarksReordered(_bookmarks);
  }

  void _removeBookmark(int index) {
    final bookmark = _bookmarks[index];
    final bookmarkId = bookmark['id'] as int? ?? index;

    setState(() {
      _bookmarks.removeAt(index);
    });

    widget.onBookmarkRemoved(bookmarkId);

    // 检查是否为空文件夹
    if (_bookmarks.isEmpty) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 480,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          color: const Color(0xFF1E1E2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.folder,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _folderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_bookmarks.length} 个书签',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                      onPressed: _showRenameDialog,
                      tooltip: '重命名',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        widget.onDissolve();
                        Navigator.pop(context);
                      },
                      tooltip: '解散文件夹',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),

              // Bookmarks grid with drag support
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _bookmarks.isEmpty
                      ? Center(
                          child: Text(
                            '文件夹为空',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _buildBookmarkGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件夹内的书签网格项（支持长按拖拽）
class _FolderBookmarkGridItem extends StatelessWidget {
  final Map<String, dynamic> bookmark;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final Function(int fromIndex) onAccept;
  final bool isDragging;

  const _FolderBookmarkGridItem({
    required super.key,
    required this.bookmark,
    required this.index,
    required this.onRemove,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAccept,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    final name = bookmark['name'] as String? ?? 'Unknown';
    final color = bookmark['color'] is Color
        ? bookmark['color'] as Color
        : Colors.blue;

    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 300),
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      onDraggableCanceled: (_, __) => onDragEnd(),
      feedback: _buildFeedback(name, color),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildItemContent(name, color, false),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            return details.data != index;
          },
          onAcceptWithDetails: (details) {
            onAccept(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            final isTarget = candidateData.isNotEmpty;
            return _buildItemContent(name, color, isTarget);
          },
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18, color: Colors.white70),
              const SizedBox(width: 12),
              Text('移出文件夹', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
      elevation: 8,
      color: const Color(0xFF2D2D3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).then((value) {
      if (value == 0) onRemove();
    });
  }

  Widget _buildItemContent(String name, Color color, bool isTarget) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 72,
      height: 96,
      child: Column(
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
              child: _buildBookmarkIcon(),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(
              name,
              style: TextStyle(
                color: isTarget ? color : Colors.white,
                fontSize: 11,
                fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(String name, Color color) {
    return Transform.scale(
      scale: 1.1,
      child: Container(
        width: 72,
        height: 96,
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
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildBookmarkIcon(),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkIcon() {
    final type = bookmark['type'] as String? ?? 'custom';
    final color = bookmark['color'] is Color
        ? bookmark['color'] as Color
        : Colors.blue;

    if (type == 'network') {
      final iconUrl = bookmark['iconUrl'] as String? ??
                     bookmark['icon_url'] as String?;
      if (iconUrl != null && iconUrl.isNotEmpty) {
        return Image.network(
          iconUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackIcon(color);
          },
        );
      }
    }

    return _buildFallbackIcon(color);
  }

  Widget _buildFallbackIcon(Color color) {
    final iconText = bookmark['iconText'] as String? ??
                     bookmark['icon_text'] as String? ??
                     (bookmark['name'] as String? ?? '?').substring(0, 1).toUpperCase();

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
}
