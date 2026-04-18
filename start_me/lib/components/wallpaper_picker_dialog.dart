import 'package:flutter/material.dart';
import '../services/wallpaper_service.dart';
import '../services/settings_service.dart';
import '../signals/app_signal.dart';

class WallpaperPickerDialog extends StatefulWidget {
  final VoidCallback onClose;

  const WallpaperPickerDialog({super.key, required this.onClose});

  @override
  State<WallpaperPickerDialog> createState() => _WallpaperPickerDialogState();
}

class _WallpaperPickerDialogState extends State<WallpaperPickerDialog> {
  static const _categories = [
    'nature',
    'landscape',
    'mountain',
    'ocean',
    'forest',
    'sky',
    'sunset',
    'city',
    'architecture',
    'minimal',
    'abstract',
    'space',
    'galaxy',
    'technology',
  ];

  int _selectedCategory = 0;
  List<Map<String, String>> _wallpapers = [];
  String? _selectedUrl;
  bool _isLoading = true;
  bool _isApplying = false;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadWallpapers();
  }

  Future<void> _loadWallpapers() async {
    setState(() {
      _isLoading = true;
      _selectedUrl = null;
    });
    final keyword = _categories[_selectedCategory];
    final wallpapers = await WallpaperService.getWallpapersByKeyword(
      keyword,
      count: 12,
    );
    if (mounted) {
      setState(() {
        _wallpapers = wallpapers;
        _isLoading = false;
      });
    }
  }

  Future<void> _apply() async {
    if (_selectedUrl == null) return;
    setState(() => _isApplying = true);
    updateWallpaper(_selectedUrl!);
    await SettingsService.set('wallpaper_url', _selectedUrl!);
    if (mounted) {
      setState(() => _isApplying = false);
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 900,
          height: 600,
          color: const Color(0xFF1E1E2E),
          child: Column(
            children: [
              _buildHeader(),
              _buildCategoryTabs(),
              Expanded(child: _buildGrid()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_library, color: Colors.blue, size: 22),
          const SizedBox(width: 10),
          const Text(
            '选壁纸',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategory == index;
          return GestureDetector(
            onTap: () {
              if (_selectedCategory != index) {
                setState(() => _selectedCategory = index);
                _loadWallpapers();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: isSelected
                    ? const Border(
                        bottom: BorderSide(color: Colors.blue, width: 2),
                      )
                    : null,
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white54,
          ),
        ),
      );
    }

    if (_wallpapers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported,
                color: Colors.white.withOpacity(0.3), size: 36),
            const SizedBox(height: 8),
            Text(
              '暂无壁纸',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 16 / 10,
      ),
      itemCount: _wallpapers.length,
      itemBuilder: (context, index) {
        final wp = _wallpapers[index];
        final url = wp['url']!;
        final thumb = wp['thumb']!;
        final isSelected = _selectedUrl == url;
        final isHovered = _hoveredIndex == index;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: GestureDetector(
            onTap: () => setState(() => _selectedUrl = url),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : isHovered
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white.withOpacity(0.08),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white.withOpacity(0.05),
                        child: const Icon(Icons.broken_image,
                            color: Colors.white24, size: 24),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Refresh
          GestureDetector(
            onTap: _isLoading ? null : _loadWallpapers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh,
                      color: Colors.white.withOpacity(0.6), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '换一批',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Apply
          GestureDetector(
            onTap: (_selectedUrl == null || _isApplying) ? null : _apply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedUrl != null
                    ? Colors.blue
                    : Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isApplying ? '应用中...' : '确认应用',
                style: TextStyle(
                  color: _selectedUrl != null
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
