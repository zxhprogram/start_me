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
import '../components/email_card.dart';
import '../components/keyboard_stats_card.dart';
import '../components/wallpaper_picker_dialog.dart';
import '../services/wallpaper_service.dart';
import '../services/settings_service.dart';
import '../services/card_order_service.dart';
import '../signals/app_signal.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingWallpaper = false;
  bool _isLoadingOrder = true;

  // 默认卡片顺序
  final List<String> _defaultCardOrder = [
    'weather',
    'hot_search',
    'calendar',
    'bookmark_shortcuts',
    'english',
    'stock',
    'todo',
    'recording',
    'holiday',
    'memo',
    'qwerty',
    'music',
    'github_trending',
    'github_feed',
    'email',
    'keyboard_stats',
  ];

  // 当前卡片顺序
  late List<String> _cardOrder;

  @override
  void initState() {
    super.initState();
    _cardOrder = List.from(_defaultCardOrder);
    _loadCardOrder();
  }

  Future<void> _loadCardOrder() async {
    setState(() => _isLoadingOrder = true);
    final savedOrder = await CardOrderService.getCardOrder();
    if (savedOrder != null && savedOrder.isNotEmpty) {
      // 过滤掉可能已删除的卡片，添加新卡片
      final validCards = _defaultCardOrder.toSet();
      final filteredOrder = savedOrder.where((id) => validCards.contains(id)).toList();
      // 添加新卡片到末尾
      final newCards = validCards.difference(filteredOrder.toSet());
      setState(() {
        _cardOrder = [...filteredOrder, ...newCards];
      });
    }
    setState(() => _isLoadingOrder = false);
  }

  Future<void> _saveCardOrder() async {
    await CardOrderService.saveCardOrder(_cardOrder);
  }

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
        const PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.photo_library, size: 18, color: Colors.white70),
              SizedBox(width: 12),
              Text('选壁纸', style: TextStyle(color: Colors.white)),
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
      } else if (value == 1) {
        _showWallpaperPicker();
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
      SettingsService.set('wallpaper_url', newWallpaperUrl);
    }

    if (mounted) {
      setState(() {
        _isLoadingWallpaper = false;
      });
    }
  }

  void _showWallpaperPicker() {
    showDialog(
      context: context,
      builder: (context) => WallpaperPickerDialog(
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// 根据卡片ID获取对应的Widget
  Widget _getCardWidget(String cardId) {
    switch (cardId) {
      case 'weather':
        return const WeatherCard();
      case 'hot_search':
        return const HotSearchCard();
      case 'calendar':
        return const CalendarCard();
      case 'bookmark_shortcuts':
        return const BookmarkShortcuts();
      case 'english':
        return const EnglishCard();
      case 'stock':
        return const StockCard();
      case 'todo':
        return const TodoCard();
      case 'recording':
        return const RecordingCard();
      case 'holiday':
        return const HolidayCard();
      case 'memo':
        return const MemoCard();
      case 'qwerty':
        return const QwertyCard();
      case 'music':
        return const MusicCard();
      case 'github_trending':
        return const GitHubTrendingCard();
      case 'github_feed':
        return const GitHubFeedCard();
      case 'email':
        return const EmailCard();
      case 'keyboard_stats':
        return const KeyboardStatsCard();
      default:
        return const SizedBox.shrink();
    }
  }

  /// 交换两个卡片的位置
  void _swapCards(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    setState(() {
      final card = _cardOrder.removeAt(oldIndex);
      // 注意：当移除元素后，如果新索引大于旧索引，需要调整
      final adjustedIndex = newIndex > oldIndex ? newIndex : newIndex;
      _cardOrder.insert(adjustedIndex, card);
    });

    // 保存新的顺序
    _saveCardOrder();
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
    if (_isLoadingOrder) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white70,
        ),
      );
    }

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

        return _ReorderableGridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 1
              ? 1.8
              : (crossAxisCount == 2 ? 1.5 : (crossAxisCount == 3 ? 1.7 : 2.0)),
          children: _cardOrder.asMap().entries.map((entry) {
            final index = entry.key;
            final cardId = entry.value;
            return _DraggableCard(
              key: ValueKey(cardId),
              index: index,
              cardId: cardId,
              child: _getCardWidget(cardId),
              onSwap: _swapCards,
            );
          }).toList(),
        );
      },
    );
  }
}

/// 可拖拽的卡片包装器
class _DraggableCard extends StatefulWidget {
  final int index;
  final String cardId;
  final Widget child;
  final Function(int oldIndex, int newIndex) onSwap;

  const _DraggableCard({
    required super.key,
    required this.index,
    required this.cardId,
    required this.child,
    required this.onSwap,
  });

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard> {
  final GlobalKey _key = GlobalKey();
  Size? _size;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSize();
    });
  }

  void _updateSize() {
    final context = _key.currentContext;
    if (context != null) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        if (mounted) {
          setState(() {
            _size = renderBox.size;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _size?.width ?? constraints.maxWidth;
        final height = _size?.height ?? constraints.maxHeight;

        return _CardDragTarget(
          index: widget.index,
          onAccept: (fromIndex) {
            widget.onSwap(fromIndex, widget.index);
          },
          child: LongPressDraggable<int>(
            data: widget.index,
            delay: const Duration(milliseconds: 500),
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.9,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: widget.child,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: widget.child,
            ),
            child: Container(
              key: _key,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// 卡片拖拽目标 - 用于接收其他卡片的拖拽
class _CardDragTarget extends StatefulWidget {
  final int index;
  final ValueChanged<int> onAccept;
  final Widget child;

  const _CardDragTarget({
    required this.index,
    required this.onAccept,
    required this.child,
  });

  @override
  State<_CardDragTarget> createState() => _CardDragTargetState();
}

class _CardDragTargetState extends State<_CardDragTarget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final willAccept = details.data != widget.index;
        if (willAccept != _isHovering) {
          setState(() => _isHovering = willAccept);
        }
        return willAccept;
      },
      onAcceptWithDetails: (details) {
        widget.onAccept(details.data);
        setState(() => _isHovering = false);
      },
      onLeave: (_) {
        if (_isHovering) {
          setState(() => _isHovering = false);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: _isHovering
                ? Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  )
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 自定义的可排序网格视图
class _ReorderableGridView extends StatelessWidget {
  final bool shrinkWrap;
  final ScrollPhysics physics;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final List<Widget> children;

  const _ReorderableGridView({
    required this.shrinkWrap,
    required this.physics,
    required this.crossAxisCount,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.childAspectRatio,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: shrinkWrap,
      physics: physics,
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
