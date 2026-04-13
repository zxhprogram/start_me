import 'package:intl/intl.dart';

class DateUtils {
  // Get current date formatted
  static String getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday]}';
  }

  // Get lunar date (simplified mock)
  static String getLunarDate() {
    final now = DateTime.now();
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

    final lunarMonth = lunarMonths[(now.month - 1) % 12];
    final lunarDayIndex = (now.day - 1) % 30;
    final lunarDay = lunarDays[lunarDayIndex];
    return '$lunarMonth月$lunarDay';
  }

  // Get full date string
  static String getFullDateString() {
    return '${getCurrentDate()} ${getLunarDate()}';
  }

  // Get day of year
  static int getDayOfYear() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }

  // Get week of year
  static int getWeekOfYear() {
    final now = DateTime.now();
    return ((getDayOfYear() - now.weekday + 10) / 7).floor();
  }

  // Generate calendar days for current month
  static List<List<int?>> generateCalendarGrid() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    List<List<int?>> weeks = [];
    List<int?> currentWeek = List.filled(7, null);

    // Fill previous month days
    for (int i = 0; i < firstWeekday; i++) {
      currentWeek[i] = null;
    }

    int day = 1;
    for (int i = firstWeekday; i < 7 && day <= daysInMonth; i++) {
      currentWeek[i] = day++;
    }
    weeks.add(currentWeek);

    // Fill remaining weeks
    while (day <= daysInMonth) {
      currentWeek = List.filled(7, null);
      for (int i = 0; i < 7 && day <= daysInMonth; i++) {
        currentWeek[i] = day++;
      }
      weeks.add(currentWeek);
    }

    return weeks;
  }

  // Check if a date is today
  static bool isToday(int day) {
    final now = DateTime.now();
    return now.day == day;
  }

  // Check if a date is weekend
  static bool isWeekend(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
