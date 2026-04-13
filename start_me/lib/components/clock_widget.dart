import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getLunarDate() {
    final lunarMonths = [
      '正',
      '二',
      '三',
      '四',
      '五',
      '六',
      '七',
      '八',
      '九',
      '十',
      '冬',
      '腊',
    ];
    final lunarDays = [
      '初一',
      '初二',
      '初三',
      '初四',
      '初五',
      '初六',
      '初七',
      '初八',
      '初九',
      '初十',
      '十一',
      '十二',
      '十三',
      '十四',
      '十五',
      '十六',
      '十七',
      '十八',
      '十九',
      '二十',
      '廿一',
      '廿二',
      '廿三',
      '廿四',
      '廿五',
      '廿六',
      '廿七',
      '廿八',
      '廿九',
      '三十',
    ];

    final lunarMonth = lunarMonths[(_now.month - 1) % 12];
    final lunarDayIndex = (_now.day - 1) % 30;
    final lunarDay = lunarDays[lunarDayIndex];
    return '$lunarMonth月$lunarDay';
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final dateStr =
        '${_now.month}月${_now.day}日 ${weekdays[_now.weekday]} ${_getLunarDate()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Large time display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('HH').format(_now),
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                height: 1,
              ),
            ),
            const Text(
              ':',
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w200,
                color: Colors.white54,
                height: 1,
              ),
            ),
            Text(
              DateFormat('mm').format(_now),
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Date display
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
