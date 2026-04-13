import 'package:flutter/material.dart';

class CalendarCard extends StatelessWidget {
  const CalendarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['日', '一', '二', '三', '四', '五', '六'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - big date
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${now.year}年${now.month}月',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${now.day}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '第${_getDayOfYear()}天 第${_getWeekOfYear()}周',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  '${_getLunarDate(now)} ${_getWeekday(now)}',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),

          // Right side - mini calendar
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Weekday headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: weekdays.map((day) {
                    return Text(
                      day,
                      style: TextStyle(
                        color: day == '日' || day == '六'
                            ? Colors.red
                            : Colors.black54,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                // Calendar days
                ..._buildCalendarRows(now),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getDayOfYear() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }

  int _getWeekOfYear() {
    final now = DateTime.now();
    return ((_getDayOfYear() - now.weekday + 10) / 7).floor();
  }

  String _getWeekday(DateTime date) {
    final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday];
  }

  String _getLunarDate(DateTime date) {
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

    final lunarMonth = lunarMonths[(date.month - 1) % 12];
    final lunarDayIndex = (date.day - 1) % 30;
    final lunarDay = lunarDays[lunarDayIndex];
    return '$lunarMonth月$lunarDay';
  }

  List<Widget> _buildCalendarRows(DateTime now) {
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    List<Widget> rows = [];
    List<Widget> currentRow = [];

    // Previous month padding
    for (int i = 0; i < firstWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox()));
    }

    int day = 1;
    while (day <= daysInMonth) {
      final isToday = day == now.day;
      final date = DateTime(now.year, now.month, day);
      final isWeekend =
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

      currentRow.add(
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: isToday ? Colors.red : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: isToday
                      ? Colors.white
                      : (isWeekend ? Colors.red : Colors.black87),
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
      day++;
    }

    // Fill remaining
    while (currentRow.length < 7) {
      currentRow.add(const Expanded(child: SizedBox()));
    }
    rows.add(Row(children: currentRow));

    return rows;
  }
}
