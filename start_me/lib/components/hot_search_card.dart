import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';

class HotSearchCard extends StatelessWidget {
  const HotSearchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D3A).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs
            Row(
              children: hotSearchTabs.asMap().entries.map((entry) {
                final isSelected = hotSearchTabIndex.value == entry.key;
                return GestureDetector(
                  onTap: () => hotSearchTabIndex.value = entry.key,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: isSelected
                          ? const Border(
                              bottom: BorderSide(color: Colors.white, width: 2),
                            )
                          : null,
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Hot search list - limited to prevent overflow
            ...hotSearchData.value.take(3).map((entry) {
              return _HotSearchItem(
                rank: entry['rank'],
                title: entry['title'],
                views: entry['views'],
              );
            }),
          ],
        ),
      );
    });
  }
}

class _HotSearchItem extends StatelessWidget {
  final int rank;
  final String title;
  final String views;

  const _HotSearchItem({
    required this.rank,
    required this.title,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    if (rank <= 3) {
      rankColor = Colors.orange;
    } else {
      rankColor = Colors.white54;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$rank',
            style: TextStyle(
              color: rankColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            views,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
