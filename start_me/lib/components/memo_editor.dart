import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../services/memo_service.dart';

class MemoEditor extends StatefulWidget {
  final List<Memo> memos;
  final Function(List<Memo>) onMemosChanged;
  final Function() onClose;

  const MemoEditor({
    super.key,
    required this.memos,
    required this.onMemosChanged,
    required this.onClose,
  });

  @override
  State<MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends State<MemoEditor> {
  late List<Memo> _memos;
  late QuillController _controller;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  int? _selectedIndex;
  bool _sortAscending = false;


  @override
  void initState() {
    super.initState();
    _memos = List.from(widget.memos);
    _controller = QuillController.basic();
    if (_memos.isNotEmpty) {
      _selectedIndex = 0;
      _loadMemoContent(_memos[0]);
    }
  }

  @override
  void dispose() {

    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadMemoContent(Memo memo) {
    _controller.dispose();
    final doc = Document()..insert(0, memo.content);
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _selectMemo(int index) {
    _autoSaveCurrent();
    setState(() {
      _selectedIndex = index;
    });
    _loadMemoContent(_filteredMemos[index]);
  }

  Future<void> _autoSaveCurrent() async {
    if (_selectedIndex == null) return;
    final memo = _filteredMemos[_selectedIndex!];
    final content = _controller.document.toPlainText().trim();
    if (content == memo.content) return;

    final updated = await MemoService.updateMemo(memo.id, content);
    if (updated != null) {
      final realIndex = _memos.indexWhere((m) => m.id == memo.id);
      if (realIndex != -1) {
        setState(() {
          _memos[realIndex] = updated;
        });
        widget.onMemosChanged(_memos);
      }
    }
  }

  Future<void> _addMemo() async {
    final now = DateTime.now();
    final title = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final memo = await MemoService.createMemo(title);
    if (memo != null) {
      setState(() {
        _memos.insert(0, memo);
        _selectedIndex = 0;
      });
      _loadMemoContent(memo);
      widget.onMemosChanged(_memos);
    }
  }

  Future<void> _deleteMemo(int id) async {
    final success = await MemoService.deleteMemo(id);
    if (success) {
      setState(() {
        _memos.removeWhere((m) => m.id == id);
        if (_memos.isEmpty) {
          _selectedIndex = null;
          _controller.dispose();
          _controller = QuillController.basic();
        } else {
          _selectedIndex = 0;
          _loadMemoContent(_filteredMemos[0]);
        }
      });
      widget.onMemosChanged(_memos);
    }
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
      _memos.sort((a, b) => _sortAscending
          ? a.updatedAt.compareTo(b.updatedAt)
          : b.updatedAt.compareTo(a.updatedAt));
      _selectedIndex = 0;
      if (_memos.isNotEmpty) _loadMemoContent(_filteredMemos[0]);
    });
  }

  List<Memo> get _filteredMemos {
    if (_searchText.isEmpty) return _memos;
    return _memos
        .where((m) => m.content.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  Memo? get _selectedMemo {
    if (_selectedIndex == null || _selectedIndex! >= _filteredMemos.length) {
      return null;
    }
    return _filteredMemos[_selectedIndex!];
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateFull(DateTime dt) {
    return '${dt.year}-${dt.month}-${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _memoTitle(Memo memo) {
    final content = memo.content.trim();
    if (content.isEmpty) return '无标题';
    final firstLine = content.split('\n').first;
    return firstLine.length > 20 ? '${firstLine.substring(0, 20)}...' : firstLine;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMemos;
    final selected = _selectedMemo;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 900,
          height: 600,
          color: Colors.white,
          child: Row(
            children: [
              // === Left panel: memo list ===
              Container(
                width: 240,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Row(
                        children: [
                          const Text(
                            '备忘录',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _toggleSort,
                            child: Icon(
                              Icons.swap_vert,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'search',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                              _selectedIndex = filtered.isNotEmpty ? 0 : null;
                              if (_selectedIndex != null) {
                                _loadMemoContent(filtered[0]);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Memo list
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final memo = filtered[index];
                          final isSelected = index == _selectedIndex;
                          return InkWell(
                            onTap: () => _selectMemo(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.05)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _memoTitle(memo),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(memo.updatedAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Add button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FloatingActionButton.small(
                        backgroundColor: Colors.purple.shade300,
                        onPressed: _addMemo,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // === Right panel: editor ===
              Expanded(
                child: selected == null
                    ? const Center(
                        child: Text(
                          '选择或创建一条备忘录',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          // Top bar: title + actions
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _memoTitle(selected),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.open_in_new,
                                      size: 18, color: Colors.grey.shade500),
                                  onPressed: () {},
                                  tooltip: '打开',
                                ),
                                IconButton(
                                  icon: Icon(Icons.fullscreen,
                                      size: 20, color: Colors.grey.shade500),
                                  onPressed: () {},
                                  tooltip: '全屏',
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 20, color: Colors.grey.shade500),
                                  onPressed: widget.onClose,
                                  tooltip: '关闭',
                                ),
                              ],
                            ),
                          ),
                          // Editor area
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                              child: QuillEditor.basic(
                                controller: _controller,
                                config: const QuillEditorConfig(
                                  placeholder: '请输入笔记内容',
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ),
                          // Footer: timestamps
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '最后编辑：${_formatDateFull(selected.updatedAt)}, '
                                  '创建：${_formatDateFull(selected.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _deleteMemo(selected.id),
                                  child: Icon(Icons.delete_outline,
                                      size: 16, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
