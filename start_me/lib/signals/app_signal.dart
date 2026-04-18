import 'package:flutter/material.dart';
import 'package:signals/signals.dart';
import '../services/weather_service.dart';

// App-wide signals
final selectedNavIndex = signal<int>(0);
final searchText = signal<String>('');

// Navigation items - now a signal for dynamic updates
final navItems = signal<List<Map<String, dynamic>>>([
  {'icon': Icons.home, 'label': '主页'},
  {'icon': Icons.code, 'label': '程序员'},
  {'icon': Icons.design_services, 'label': '设计'},
  {'icon': Icons.shopping_bag, 'label': '产品'},
  {'icon': Icons.work, 'label': 'work'},
  {'icon': Icons.book, 'label': 'study'},
  {'icon': Icons.folder, 'label': '文档'},
  {'icon': Icons.build, 'label': '工具'},
  {'icon': Icons.navigation, 'label': '导航'},
  {'icon': Icons.calculate, 'label': '数学'},
  {'icon': Icons.games, 'label': '摸鱼'},
]);

// Available icons for new groups
final availableIcons = [
  {'icon': Icons.home, 'name': 'home'},
  {'icon': Icons.favorite, 'name': 'favorite'},
  {'icon': Icons.music_note, 'name': 'music'},
  {'icon': Icons.chat, 'name': 'chat'},
  {'icon': Icons.work_outline, 'name': 'work'},
  {'icon': Icons.movie, 'name': 'movie'},
  {'icon': Icons.shopping_bag, 'name': 'shopping'},
  {'icon': Icons.code, 'name': 'code'},
  {'icon': Icons.school, 'name': 'school'},
  {'icon': Icons.book, 'name': 'book'},
  {'icon': Icons.build, 'name': 'build'},
  {'icon': Icons.thumb_up, 'name': 'like'},
  {'icon': Icons.star, 'name': 'star'},
  {'icon': Icons.local_hospital, 'name': 'hospital'},
  {'icon': Icons.flight, 'name': 'flight'},
  {'icon': Icons.article, 'name': 'article'},
  {'icon': Icons.grid_view, 'name': 'grid'},
  {'icon': Icons.eco, 'name': 'eco'},
  {'icon': Icons.image, 'name': 'image'},
  {'icon': Icons.emoji_events, 'name': 'award'},
  {'icon': Icons.fitness_center, 'name': 'fitness'},
  {'icon': Icons.local_parking, 'name': 'parking'},
  {'icon': Icons.send, 'name': 'send'},
  {'icon': Icons.flag, 'name': 'flag'},
  {'icon': Icons.bookmark, 'name': 'bookmark'},
  {'icon': Icons.delete_outline, 'name': 'delete'},
];

final hotSearchTabIndex = signal<int>(0);

// 已订阅的热搜数据源（nodeId + name）
final subscribedNodes = signal<List<Map<String, dynamic>>>([
  {'id': 6, 'name': '知乎'},
  {'id': 2, 'name': '百度'},
  {'id': 1, 'name': '微博'},
]);

// Weather data signal - stores full WeatherData from API
final fullWeatherData = signal<WeatherData?>(null);

// Weather location (for city switching)
final weatherLocation = signal<Map<String, dynamic>>({
  'lat': 39.8585,
  'lon': 116.2867,
  'name': '北京市·丰台',
});

// Hot search data - key is nodeId, value is list of hot items
final hotSearchData = signal<Map<int, List<Map<String, dynamic>>>>({});

// Stock data - Global indices (default values, will be updated on app load)
final stockData = signal<List<Map<String, dynamic>>>([
  {'name': '日经 225', 'code': 'NIKKI', 'price': '', 'change': ''},
  {'name': '恒生指数', 'code': 'HSI', 'price': '', 'change': ''},
  {'name': '道琼斯', 'code': 'DJIA', 'price': '', 'change': ''},
  {'name': '标普 500', 'code': 'SP500', 'price': '', 'change': ''},
  {'name': '德国 DAX', 'code': 'DAX', 'price': '', 'change': ''},
]);

// Todo count
final todoCount = signal<int>(0);

// Holiday data
final holidayData = signal<Map<String, dynamic>>({
  'next': {'name': '劳动节还有', 'days': 18, 'date': '5.1-5.5'},
  'upcoming': [
    {'name': '端午节', 'date': '6.19-6.21', 'days': 67},
    {'name': '中秋节', 'date': '9.25-9.27', 'days': 165},
    {'name': '国庆节', 'date': '10.1-10.7', 'days': 171},
  ],
});

// Memo data
final memoList = signal<List<String>>(['mybatis 生成sql位置', '重点', '工作日志']);

// Daily quote
final dailyQuote = signal<String>('「一切幸福都并非没有烦恼，而一切逆境也绝非没有希望。」');

// English quote
final englishQuote = signal<Map<String, String>>({
  'en': 'Your potential is a universe; don\'t settle for being a single star.',
  'cn': '你的潜力是一个宇宙，别满足于做一颗孤星。',
});

// Search engines
final selectedSearchEngine = signal<int>(1); // 默认选中必应

final searchEngines = [
  {
    'name': '百度',
    'icon': Icons.search,
    'color': Colors.blue,
    'url': 'https://www.baidu.com/s?wd=',
  },
  {
    'name': '必应',
    'icon': Icons.search,
    'color': Colors.blue,
    'url': 'https://www.bing.com/search?q=',
  },
  {
    'name': 'Google',
    'icon': Icons.search,
    'color': Colors.red,
    'url': 'https://www.google.com/search?q=',
  },
  {
    'name': 'gitHub',
    'icon': Icons.code,
    'color': Colors.black,
    'url': 'https://github.com/search?q=',
  },
  {
    'name': 'DuckDuckGo',
    'icon': Icons.privacy_tip,
    'color': Colors.orange,
    'url': 'https://duckduckgo.com/?q=',
  },
  {
    'name': '开发者搜索',
    'icon': Icons.developer_mode,
    'color': Colors.blue,
    'url': 'https://kaifa.baidu.com/search?query=',
  },
];

// Group icons data - each group has a list of icons
// Key is group label, value is list of icons with name and icon data
final groupIcons = signal<Map<String, List<Map<String, dynamic>>>>({
  '主页': [], // Home uses dashboard cards, not icons
  '程序员': [],
  '设计': [],
  '产品': [],
  'work': [],
  'study': [],
  '文档': [],
  '工具': [],
  '导航': [],
  '数学': [],
  '摸鱼': [],
});

// Icons available for adding to groups (Material icons as placeholders)
final groupAvailableIcons = [
  {'icon': Icons.code, 'name': 'VS Code', 'color': Colors.blue},
  {'icon': Icons.terminal, 'name': 'Terminal', 'color': Colors.grey},
  {'icon': Icons.web, 'name': 'Web', 'color': Colors.green},
  {'icon': Icons.storage, 'name': 'Database', 'color': Colors.orange},
  {'icon': Icons.cloud, 'name': 'Cloud', 'color': Colors.lightBlue},
  {'icon': Icons.bug_report, 'name': 'Debug', 'color': Colors.red},
  {'icon': Icons.design_services, 'name': 'Figma', 'color': Colors.purple},
  {'icon': Icons.palette, 'name': 'Design', 'color': Colors.pink},
  {'icon': Icons.brush, 'name': 'Paint', 'color': Colors.deepPurple},
  {'icon': Icons.format_paint, 'name': 'Sketch', 'color': Colors.yellow},
  {'icon': Icons.shopping_bag, 'name': 'Shop', 'color': Colors.green},
  {'icon': Icons.shopping_cart, 'name': 'Cart', 'color': Colors.orange},
  {'icon': Icons.trending_up, 'name': 'Analytics', 'color': Colors.blue},
  {'icon': Icons.pie_chart, 'name': 'Chart', 'color': Colors.teal},
  {'icon': Icons.folder, 'name': 'Files', 'color': Colors.amber},
  {'icon': Icons.insert_drive_file, 'name': 'Docs', 'color': Colors.blue},
  {'icon': Icons.note, 'name': 'Notes', 'color': Colors.yellow},
  {'icon': Icons.event_note, 'name': 'Events', 'color': Colors.red},
  {'icon': Icons.calculate, 'name': 'Calculator', 'color': Colors.indigo},
  {'icon': Icons.functions, 'name': 'Math', 'color': Colors.deepPurple},
  {'icon': Icons.science, 'name': 'Science', 'color': Colors.green},
  {'icon': Icons.biotech, 'name': 'Bio', 'color': Colors.teal},
  {'icon': Icons.sports_esports, 'name': 'Games', 'color': Colors.purple},
  {'icon': Icons.gamepad, 'name': 'Play', 'color': Colors.orange},
  {'icon': Icons.movie, 'name': 'Movie', 'color': Colors.red},
  {'icon': Icons.music_note, 'name': 'Music', 'color': Colors.pink},
  {'icon': Icons.book, 'name': 'Book', 'color': Colors.brown},
  {'icon': Icons.school, 'name': 'Learn', 'color': Colors.blue},
  {'icon': Icons.language, 'name': 'Translate', 'color': Colors.green},
  {'icon': Icons.map, 'name': 'Map', 'color': Colors.green},
  {'icon': Icons.navigation, 'name': 'Navigate', 'color': Colors.blue},
  {'icon': Icons.location_on, 'name': 'Location', 'color': Colors.red},
];

// Helper function to add icon to a group
void addIconToGroup(String groupLabel, Map<String, dynamic> icon) {
  final current = Map<String, List<Map<String, dynamic>>>.from(
    groupIcons.value,
  );
  if (current.containsKey(groupLabel)) {
    current[groupLabel] = [...current[groupLabel]!, icon];
    groupIcons.value = current;
  }
}

// Helper function to reorder icons in a group
void reorderGroupIcons(String groupLabel, int oldIndex, int newIndex) {
  final current = Map<String, List<Map<String, dynamic>>>.from(
    groupIcons.value,
  );
  if (current.containsKey(groupLabel)) {
    final icons = [...current[groupLabel]!];
    if (oldIndex >= 0 &&
        oldIndex < icons.length &&
        newIndex >= 0 &&
        newIndex < icons.length) {
      final item = icons.removeAt(oldIndex);
      icons.insert(newIndex, item);
      current[groupLabel] = icons;
      groupIcons.value = current;
    }
  }
}

// Helper function to remove a group from navItems
void removeGroup(int index) {
  if (index >= 0 && index < navItems.value.length) {
    final currentItems = [...navItems.value];
    final removedLabel = currentItems[index]['label'] as String;
    currentItems.removeAt(index);
    navItems.value = currentItems;

    // Also remove the group icons data
    final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
      groupIcons.value,
    );
    currentIcons.remove(removedLabel);
    groupIcons.value = currentIcons;

    // Reset selected index if needed
    if (selectedNavIndex.value == index) {
      selectedNavIndex.value = 0; // Jump to home
    } else if (selectedNavIndex.value > index) {
      selectedNavIndex.value = selectedNavIndex.value - 1;
    }
  }
}

// Helper function to edit a group
void editGroup(int index, IconData icon, String label) {
  if (index >= 0 && index < navItems.value.length) {
    final currentItems = [...navItems.value];
    final oldLabel = currentItems[index]['label'] as String;

    // Update the group info
    currentItems[index] = {'icon': icon, 'label': label};
    navItems.value = currentItems;

    // Also update the group icons data key if label changed
    if (oldLabel != label) {
      final currentIcons = Map<String, List<Map<String, dynamic>>>.from(
        groupIcons.value,
      );
      if (currentIcons.containsKey(oldLabel)) {
        currentIcons[label] = currentIcons.remove(oldLabel)!;
        groupIcons.value = currentIcons;
      }
    }
  }
}

// Current wallpaper URL signal
final currentWallpaperUrl = signal<String>(
  'https://files.codelife.cc/wallhaven/full/rd/wallhaven-rd7drw.jpg?x-oss-process=image/resize,limit_0,m_fill,w_1728,h_973/quality,Q_93/format,webp',
);

// Function to update wallpaper
void updateWallpaper(String url) {
  currentWallpaperUrl.value = url;
}

// GitHub Trending data signal (using Map from github_service.dart)
// Note: TrendingRepo class is defined in github_service.dart
final githubTrendingData = signal<Map<String, List<dynamic>>>({
  'daily': [],
  'weekly': [],
  'monthly': [],
});

// Current GitHub Trending period signal
final githubTrendingPeriod = signal<String>('daily');

// GitHub OAuth signals
final githubToken = signal<String>('');
final githubUser = signal<Map<String, String>>({});
final isGithubLoggedIn = computed(() => githubToken.value.isNotEmpty);
