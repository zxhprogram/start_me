import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/hot_search_service.dart';
import 'hot_search_dialog.dart';

class HotSearchCard extends StatefulWidget {
  const HotSearchCard({super.key});

  @override
  State<HotSearchCard> createState() => _HotSearchCardState();
}

class _HotSearchCardState extends State<HotSearchCard> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllSubscribed();
  }

  Future<void> _loadAllSubscribed() async {
    setState(() => _isLoading = true);
    final nodes = subscribedNodes.value;
    for (final node in nodes) {
      final nodeId = node['id'] as int;
      final result = await HotSearchService.getHotTopics(nodeId);
      if (mounted) {
        final current =
            Map<int, List<Map<String, dynamic>>>.from(hotSearchData.value);
        current[nodeId] = result['data'] as List<Map<String, dynamic>>;
        hotSearchData.value = current;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _openDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HotSearchDialog(
        onClose: () {
          Navigator.pop(context);
          // Reload data in case subscriptions changed
          _loadAllSubscribed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final nodes = subscribedNodes.value;
      final tabIndex = hotSearchTabIndex.value;
      final safeIndex = tabIndex.clamp(0, nodes.isEmpty ? 0 : nodes.length - 1);

      return GestureDetector(
        onTap: _openDialog,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D3A).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tabs
              SizedBox(
                height: 28,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final isSelected = safeIndex == index;
                    return GestureDetector(
                      onTap: () => hotSearchTabIndex.value = index,
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          border: isSelected
                              ? const Border(
                                  bottom: BorderSide(
                                      color: Colors.white, width: 2),
                                )
                              : null,
                        ),
                        child: Text(
                          nodes[index]['name'] as String,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : Colors.white54,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Content
              Expanded(
                child: _isLoading
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
                    : _buildList(nodes, safeIndex),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildList(List<Map<String, dynamic>> nodes, int safeIndex) {
    if (nodes.isEmpty) {
      return Center(
        child: Text(
          '暂无订阅源',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    final nodeId = nodes[safeIndex]['id'] as int;
    final allData = hotSearchData.value;
    final items = allData[nodeId] ?? [];

    if (items.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length > 4 ? 4 : items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final rank = item['rank'] as int? ?? (index + 1);
        final title = item['title'] as String? ?? '';
        final hot = item['hot'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank <= 3 ? Colors.orange : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hot.isNotEmpty)
                Text(
                  hot,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
