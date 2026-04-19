import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/keyboard_hook_service.dart';
import '../services/keystroke_service.dart';
import 'keyboard_stats_dialog.dart';

class KeyboardStatsCard extends StatefulWidget {
  const KeyboardStatsCard({super.key});

  @override
  State<KeyboardStatsCard> createState() => _KeyboardStatsCardState();
}

class _KeyboardStatsCardState extends State<KeyboardStatsCard> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _startSyncTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!keyboardMonitorEnabled.value) return;
      final counts = KeyboardHookService.getKeyCounts();
      if (counts.isNotEmpty) {
        await KeystrokeService.syncCounts(counts);
        KeyboardHookService.resetCounts();
      }
      final top = await KeystrokeService.getTopKeys();
      topKeystrokes.value = top;
    });
  }

  void _openDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => const KeyboardStatsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openDialog,
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Watch((context) {
        final enabled = keyboardMonitorEnabled.value;
        final keys = topKeystrokes.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: !enabled
                  ? Center(
                      child: Text(
                        '键盘监控未启用',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : keys.isEmpty
                      ? Center(
                          child: Text(
                            '暂无按键数据',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : _buildKeyList(keys),
            ),
          ],
        );
      }),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.keyboard_outlined, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Text(
          '按键统计',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Watch((context) {
          final enabled = keyboardMonitorEnabled.value;
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? Colors.greenAccent : Colors.white24,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildKeyList(List<Map<String, dynamic>> keys) {
    final maxCount = keys.isNotEmpty
        ? (keys.first['count'] as num? ?? 1).toDouble()
        : 1.0;

    return ListView.separated(
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = keys[index];
        final key = item['key'] as String? ?? '';
        final count = (item['count'] as num? ?? 0).toInt();
        final ratio = maxCount > 0 ? count / maxCount : 0.0;

        final colors = [
          Colors.blue,
          Colors.purple,
          Colors.teal,
        ];
        final color = colors[index % colors.length];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      color: color.shade200,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$count 次',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(color.withOpacity(0.7)),
              ),
            ),
          ],
        );
      },
    );
  }
}
