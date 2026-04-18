import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../components/sidebar.dart';
import '../components/clock_widget.dart';
import '../components/search_bar.dart';
import '../components/weather_card.dart';
import '../components/hot_search_card.dart';
import '../components/calendar_card.dart';
import '../components/bookmark_shortcuts.dart';
import '../components/english_card.dart';
import '../components/stock_card.dart';
import '../components/todo_card.dart';
import '../components/recording_card.dart';
import '../components/holiday_card.dart';
import '../components/memo_card.dart';
import '../components/qwerty_card.dart';
import '../components/daily_quote.dart';
import '../components/group_icons_grid.dart';
import '../components/github_trending_card.dart';
import '../components/github_feed_card.dart';
import '../components/music_card.dart';
import '../services/wallpaper_service.dart';
import '../signals/app_signal.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingWallpaper = false;

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<int>(
          value: 0,
          enabled: !_isLoadingWallpaper,
          child: Row(
            children: [
              _isLoadingWallpaper
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : const Icon(
                      Icons.wallpaper,
                      size: 18,
                      color: Colors.white70,
                    ),
              const SizedBox(width: 12),
              Text(
                _isLoadingWallpaper ? '更换中...' : '换壁纸',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
      elevation: 8,
      color: const Color(0xFF2D2D3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).then((value) {
      if (value == 0 && !_isLoadingWallpaper) {
        _changeWallpaper();
      }
    });
  }

  Future<void> _changeWallpaper() async {
    setState(() {
      _isLoadingWallpaper = true;
    });

    final newWallpaperUrl = await WallpaperService.getRandomWallpaper();

    if (newWallpaperUrl != null && mounted) {
      updateWallpaper(newWallpaperUrl);
    }

    if (mounted) {
      setState(() {
        _isLoadingWallpaper = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Background image - using Watch to react to wallpaper changes
            Watch((context) {
              return Image.network(
                currentWallpaperUrl.value,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1a1a2e),
                          const Color(0xFF16213e),
                          const Color(0xFF0f3460),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),

            // Overlay
            Container(color: Colors.black.withOpacity(0.3)),

            // Main content
            Row(
              children: [
                // Sidebar
                const Sidebar(),

                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      // Fixed top area - Clock and Search
                      Container(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 24,
                          bottom: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Clock
                            const ClockWidget(),
                            const SizedBox(height: 24),
                            // Search bar
                            const SizedBox(
                              width: 800,
                              child: SearchBarWidget(),
                            ),
                          ],
                        ),
                      ),

                      // Scrollable content area
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Watch((context) {
                            final currentNavIndex = selectedNavIndex.value;
                            final navLabel =
                                navItems.value[currentNavIndex]['label']
                                    as String;

                            if (currentNavIndex == 0) {
                              return _buildDashboardCards();
                            } else {
                              return GroupIconsGrid(groupLabel: navLabel);
                            }
                          }),
                        ),
                      ),

                      // Fixed bottom area - Daily quote
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: DailyQuote(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth > 1400) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 1000) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 700) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 1
              ? 1.8
              : (crossAxisCount == 2 ? 1.5 : (crossAxisCount == 3 ? 1.7 : 2.0)),
          children: [
            const WeatherCard(),
            const HotSearchCard(),
            const CalendarCard(),
            const BookmarkShortcuts(),
            const EnglishCard(),
            const StockCard(),
            const TodoCard(),
            const RecordingCard(),
            const HolidayCard(),
            const MemoCard(),
            const QwertyCard(),
            const MusicCard(),
            const GitHubTrendingCard(),
            const GitHubFeedCard(),
          ],
        );
      },
    );
  }
}
