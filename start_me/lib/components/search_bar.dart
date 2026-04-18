import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _hideOverlay();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent background to catch taps outside
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideOverlay,
            child: Container(color: Colors.transparent),
          ),
          // Dropdown positioned directly below the search bar
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {}, // Prevent tap from closing
                child: _buildEngineDropdown(),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _selectEngine(int index) {
    selectedSearchEngine.value = index;
    _hideOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final currentEngine = searchEngines[selectedSearchEngine.value];

      return CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _toggleOverlay,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEngineIconInSearchBar(currentEngine),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '输入搜索内容',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildEngineDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Watch((context) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...searchEngines.asMap().entries.map((entry) {
              final engine = entry.value;
              final isSelected = selectedSearchEngine.value == entry.key;
              return _buildEngineItem(engine, entry.key, isSelected);
            }),
            _buildAddButton(),
          ],
        );
      }),
    );
  }

  Widget _buildEngineItem(
    Map<String, dynamic> engine,
    int index,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => _selectEngine(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? (engine['color'] as Color).withOpacity(0.15)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: engine['color'] as Color, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: _buildEngineIconInDropdown(engine),
            ),
            const SizedBox(height: 4),
            Text(
              engine['name'] as String,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.black54,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.add, color: Colors.grey, size: 22),
            ),
            const SizedBox(height: 4),
            const Text(
              '添加',
              style: TextStyle(color: Colors.black54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineIconInDropdown(Map<String, dynamic> engine) {
    final name = engine['name'] as String;

    if (name == '百度') {
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'du',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    } else if (name == '必应') {
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.blue, Colors.cyan]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              'B',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    } else if (name == 'Google') {
      return const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      );
    } else if (name == 'gitHub') {
      return const Center(
        child: Icon(Icons.code, color: Colors.black, size: 28),
      );
    } else if (name == 'DuckDuckGo') {
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.privacy_tip, color: Colors.white, size: 18),
          ),
        ),
      );
    } else if (name == '开发者搜索') {
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.developer_mode, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        engine['icon'] as IconData,
        color: engine['color'] as Color,
        size: 24,
      ),
    );
  }

  Widget _buildEngineIconInSearchBar(Map<String, dynamic> engine) {
    final name = engine['name'] as String;

    if (name == '百度') {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: const Center(
          child: Text(
            'du',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    } else if (name == '必应') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.blue, Colors.cyan]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'B',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    } else if (name == 'Google') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'G',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    } else if (name == 'gitHub') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.code, color: Colors.white, size: 20),
        ),
      );
    } else if (name == 'DuckDuckGo') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.privacy_tip, color: Colors.white, size: 20),
        ),
      );
    } else if (name == '开发者搜索') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.developer_mode, color: Colors.white, size: 20),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: engine['color'] as Color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(engine['icon'] as IconData, color: Colors.white, size: 20),
      ),
    );
  }
}
