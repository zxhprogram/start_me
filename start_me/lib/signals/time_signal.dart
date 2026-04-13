import 'package:signals/signals.dart';
import 'package:intl/intl.dart';

// Time signals that update every second
final currentTime = signal<DateTime>(DateTime.now());
final currentHour = signal<String>('09');
final currentMinute = signal<String>('05');
final currentDate = signal<String>('4月13日 星期一 二月廿六');

// Initialize time updates
void initTimeSignals() {
  // Update immediately
  _updateTime();

  // Update every second
  Stream.periodic(const Duration(seconds: 1)).listen((_) {
    _updateTime();
  });
}

void _updateTime() {
  final now = DateTime.now();
  currentTime.value = now;

  // Format hour and minute
  currentHour.value = DateFormat('HH').format(now);
  currentMinute.value = DateFormat('mm').format(now);

  // Format date with lunar (simplified)
  final weekdays = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  final lunarDate = _getLunarDate(now);
  currentDate.value =
      '${now.month}月${now.day}日 ${weekdays[now.weekday]} $lunarDate';
}

// Simplified lunar date calculation (mock)
String _getLunarDate(DateTime date) {
  // This is a simplified mock - in real app, use lunar calendar library
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

  // Mock lunar date based on current date
  final lunarMonth = lunarMonths[(date.month) % 12];
  final lunarDay = lunarDays[(date.day % 30)];
  return '$lunarMonth月$lunarDay';
}
