import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../signals/app_signal.dart';
import '../services/search_suggestion_service.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  // Engine selector overlay
  OverlayEntry? _overlayEntry;

  // Suggestion overlay
  OverlayEntry? _suggestionOverlay;
  List<String> _suggestions = [];
  int _selectedIndex = -1;
  Timer? _debounceTimer;
  bool _isSelectingSuggestion = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _hideOverlay();
    _hideSuggestions();
    super.dispose();
  }

  // ========== Engine Selector ==========

  void _showOverlay() {
    _hideOverlay();
    _hideSuggestions();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideOverlay,
            child: Container(color: Colors.transparent),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {},
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
    _suggestions = [];
    _selectedIndex = -1;
    _hideSuggestions();
  }

  // ========== Suggestions ==========

  void _onTextChanged(String text) {
    _isSelectingSuggestion = false;
    _selectedIndex = -1;
    _debounceTimer?.cancel();

    if (text.trim().isEmpty) {
      _suggestions = [];
      _hideSuggestions();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final engine =
          searchEngines[selectedSearchEngine.value]['name'] as String;
      final results =
          await SearchSuggestionService.getSuggestions(text, engine: engine);
      if (mounted && _controller.text == text && !_isSelectingSuggestion) {
        _suggestions = results;
        _selectedIndex = -1;
        if (_suggestions.isNotEmpty) {
          _showSuggestions();
        } else {
          _hideSuggestions();
        }
      }
    });
  }

  void _showSuggestions() {
    _hideSuggestions();
    _hideOverlay();

    final overlay = Overlay.of(context);
    _suggestionOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideSuggestions,
            child: Container(color: Colors.transparent),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              color: Colors.transparent,
              child: _buildSuggestionList(),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_suggestionOverlay!);
  }

  void _hideSuggestions() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  void _updateSuggestionOverlay() {
    if (_suggestionOverlay != null) {
      _suggestionOverlay!.markNeedsBuild();
    }
  }

  void _selectSuggestion(String text) {
    _isSelectingSuggestion = true;
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _suggestions = [];
    _selectedIndex = -1;
    _hideSuggestions();
    _focusNode.requestFocus();
  }

  void _doSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    _hideSuggestions();
    final engineUrl =
        searchEngines[selectedSearchEngine.value]['url'] as String;
    final searchUrl = '$engineUrl${Uri.encodeComponent(query)}';
    launchUrl(Uri.parse(searchUrl), mode: LaunchMode.externalApplication);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_suggestions.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _doSearch();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex =
            (_selectedIndex + 1).clamp(0, _suggestions.length - 1);
      });
      _controller.text = _suggestions[_selectedIndex];
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _isSelectingSuggestion = true;
      _updateSuggestionOverlay();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_selectedIndex <= 0) {
          _selectedIndex = -1;
        } else {
          _selectedIndex--;
        }
      });
      if (_selectedIndex >= 0) {
        _controller.text = _suggestions[_selectedIndex];
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        _isSelectingSuggestion = true;
      }
      _updateSuggestionOverlay();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
        _selectSuggestion(_suggestions[_selectedIndex]);
      } else {
        _doSearch();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _suggestions = [];
      _selectedIndex = -1;
      _hideSuggestions();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ========== Build ==========

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
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onTextChanged,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '输入搜索内容',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                onPressed: _doSearch,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSuggestionList() {
    return Container(
      width: 800,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D3A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final isSelected = index == _selectedIndex;
            return GestureDetector(
              onTap: () => _selectSuggestion(_suggestions[index]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: isSelected
                    ? Colors.white.withOpacity(0.12)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.35),
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _suggestions[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.75),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.north_west,
                        color: Colors.white.withOpacity(0.3),
                        size: 14,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ========== Engine Dropdown (unchanged logic) ==========

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
