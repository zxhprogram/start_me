import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hot_search_service.dart';
import '../signals/app_signal.dart';

class HotSearchDialog extends StatefulWidget {
  final VoidCallback onClose;

  const HotSearchDialog({super.key, required this.onClose});

  @override
  State<HotSearchDialog> createState() => _HotSearchDialogState();
}

class _HotSearchDialogState extends State<HotSearchDialog> {
  // Categories
  static const _categories = [
    '我的订阅',
    '全部',
    '综合',
    '科技',
    '娱乐',
    '社区',
    '财经',
  ];

  int _selectedCategory = 0;
  int _selectedNodeId = -1;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allNodes = [];
  List<Map<String, dynamic>> _currentItems = [];
  String _currentSitename = '';
  String _currentLogo = '';
  bool _isLoadingItems = false;
  bool _isLoadingNodes = true;

  // Track subscribed node IDs
  late List<Map<String, dynamic>> _subscribed;
  bool _subscriptionChanged = false;

  @override
  void initState() {
    super.initState();
    _subscribed =
        List<Map<String, dynamic>>.from(subscribedNodes.value);
    _loadNodes();
    // Auto-select first subscribed node
    if (_subscribed.isNotEmpty) {
      _selectedNodeId = _subscribed[0]['id'] as int;
      _loadItems(_selectedNodeId);
    }
  }

  Future<void> _loadNodes() async {
    final nodes = await HotSearchService.getNodes();
    if (mounted) {
      setState(() {
        _allNodes = nodes;
        _isLoadingNodes = false;
      });
    }
  }

  Future<void> _loadItems(int nodeId) async {
    setState(() {
      _isLoadingItems = true;
      _selectedNodeId = nodeId;
    });
    final result = await HotSearchService.getHotTopics(nodeId);
    if (mounted) {
      setState(() {
        _currentItems = result['data'] as List<Map<String, dynamic>>;
        _currentSitename = result['sitename'] as String? ?? '';
        _currentLogo = result['logo'] as String? ?? '';
        _isLoadingItems = false;
      });
    }
  }

  bool _isSubscribed(int nodeId) {
    return _subscribed.any((n) => n['id'] == nodeId);
  }

  void _addSubscription(int nodeId, String name) {
    setState(() {
      if (!_isSubscribed(nodeId)) {
        _subscribed.add({'id': nodeId, 'name': name});
        _subscriptionChanged = true;
      }
    });
  }

  void _removeSubscription(int nodeId) {
    setState(() {
      _subscribed.removeWhere((n) => n['id'] == nodeId);
      _subscriptionChanged = true;
    });
  }

  List<Map<String, dynamic>> _getFilteredNodes() {
    List<Map<String, dynamic>> nodes;

    if (_selectedCategory == 0) {
      // 我的订阅
      nodes = _subscribed.map((sub) {
        final nodeId = sub['id'] as int;
        final match = _allNodes.where((n) => n['id'] == nodeId);
        if (match.isNotEmpty) return match.first;
        return {'id': nodeId, 'name': sub['name'], 'category': '', 'logo': ''};
      }).toList();
    } else if (_selectedCategory == 1) {
      // 全部
      nodes = _allNodes;
    } else {
      final cat = _categories[_selectedCategory];
      nodes = _allNodes.where((n) => n['category'] == cat).toList();
    }

    if (_searchQuery.isNotEmpty) {
      nodes = nodes
          .where((n) => (n['name'] as String? ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return nodes;
  }

  void _handleClose() {
    if (_subscriptionChanged) {
      subscribedNodes.value = List.from(_subscribed);
      // Persist to SharedPreferences
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('subscribed_nodes', jsonEncode(_subscribed));
      });
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 900,
          height: 600,
          color: const Color(0xFF1E1E2E),
          child: Column(
            children: [
              _buildHeader(),
              _buildCategoryTabs(),
              Expanded(
                child: Row(
                  children: [
                    _buildLeftPanel(),
                    Container(
                      width: 1,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    Expanded(child: _buildRightPanel()),
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
          const Icon(Icons.local_fire_department,
              color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          const Text(
            '热搜榜',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: _handleClose,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategory == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = index;
                _searchQuery = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: isSelected
                    ? const Border(
                        bottom:
                            BorderSide(color: Colors.orange, width: 2),
                      )
                    : null,
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftPanel() {
    final nodes = _getFilteredNodes();

    return SizedBox(
      width: 200,
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索',
                hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withOpacity(0.3), size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Node list
          Expanded(
            child: _isLoadingNodes
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : nodes.isEmpty
                    ? Center(
                        child: Text(
                          '暂无数据源',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          final nodeId = node['id'] as int;
                          final name = node['name'] as String? ?? '';
                          final logo = node['logo'] as String? ?? '';
                          final isSelected = nodeId == _selectedNodeId;
                          final isSub = _isSubscribed(nodeId);

                          return GestureDetector(
                            onTap: () => _loadItems(nodeId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              margin:
                                  const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  // Logo
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: logo.isNotEmpty
                                        ? Image.network(
                                            logo,
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                    _defaultLogo(),
                                          )
                                        : _defaultLogo(),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white
                                                .withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Action button
                                  if (_selectedCategory == 0)
                                    // 我的订阅 — show remove
                                    GestureDetector(
                                      onTap: () =>
                                          _removeSubscription(
                                              nodeId),
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.white
                                            .withOpacity(0.3),
                                        size: 16,
                                      ),
                                    )
                                  else
                                    // Categories — show add/check
                                    GestureDetector(
                                      onTap: isSub
                                          ? () =>
                                              _removeSubscription(
                                                  nodeId)
                                          : () =>
                                              _addSubscription(
                                                  nodeId, name),
                                      child: Icon(
                                        isSub
                                            ? Icons.check_circle
                                            : Icons
                                                .add_circle_outline,
                                        color: isSub
                                            ? Colors.green
                                                .withOpacity(0.7)
                                            : Colors.white
                                                .withOpacity(0.3),
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _defaultLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.public, color: Colors.white54, size: 14),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedNodeId < 0) {
      return Center(
        child: Text(
          '请选择一个数据源',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Title bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              if (_currentLogo.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _currentLogo,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              if (_currentLogo.isNotEmpty) const SizedBox(width: 8),
              Text(
                _currentSitename.isNotEmpty
                    ? _currentSitename
                    : '热榜',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '·  24小时热榜',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isLoadingItems
                    ? null
                    : () => _loadItems(_selectedNodeId),
                child: Icon(
                  Icons.refresh,
                  color: Colors.white.withOpacity(0.4),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        // Items list
        Expanded(
          child: _isLoadingItems
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white54))
              : _currentItems.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: _currentItems.length,
                      itemBuilder: (context, index) {
                        final item = _currentItems[index];
                        return _buildItemRow(item, index);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item, int index) {
    final rank = item['rank'] as int? ?? (index + 1);
    final title = item['title'] as String? ?? '';
    final hot = item['hot'] as String? ?? '';
    final url = item['url'] as String? ?? '';

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFF4D4F);
    } else if (rank == 2) {
      rankColor = const Color(0xFFFF7A45);
    } else if (rank == 3) {
      rankColor = const Color(0xFFFFA940);
    } else {
      rankColor = Colors.white38;
    }

    return GestureDetector(
      onTap: url.isNotEmpty
          ? () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: rankColor,
                  fontSize: 14,
                  fontWeight:
                      rank <= 3 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hot.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  hot,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
