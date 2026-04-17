import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WordItem {
  final String word;
  final String meaning;
  WordItem({required this.word, required this.meaning});
}

enum CharState { pending, correct, wrong }

class QwertyPracticeDialog extends StatefulWidget {
  const QwertyPracticeDialog({super.key});

  @override
  State<QwertyPracticeDialog> createState() => _QwertyPracticeDialogState();
}

class _QwertyPracticeDialogState extends State<QwertyPracticeDialog> {
  static const int _wordsPerChapter = 20;

  List<WordItem> _allWords = [];
  int _chapter = 0;
  int _wordIndexInChapter = 0;
  WordItem? _currentWord;
  List<CharState> _charStates = [];
  int _cursorIndex = 0;

  // stats
  int _totalTyped = 0;
  int _correctCount = 0;
  DateTime? _startTime;
  Timer? _timer;
  int _elapsedSeconds = 0;

  bool _isPaused = false;
  bool _showMeaning = true;
  bool _shuffle = false;
  bool _isLoaded = false;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final raw = await rootBundle.loadString('assets/words/四级.txt');
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    _allWords = lines.map((line) {
      final parts = line.split('\t');
      return WordItem(
        word: parts[0].trim(),
        meaning: parts.length > 1 ? parts[1].trim() : '',
      );
    }).toList();

    setState(() {
      _isLoaded = true;
      _startChapter();
    });
  }

  void _startChapter() {
    if (_shuffle) {
      _allWords.shuffle();
    }
    _wordIndexInChapter = 0;
    _totalTyped = 0;
    _correctCount = 0;
    _elapsedSeconds = 0;
    _startTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
    _loadCurrentWord();
  }

  void _loadCurrentWord() {
    final globalIndex = _chapter * _wordsPerChapter + _wordIndexInChapter;
    if (globalIndex >= _allWords.length) {
      // wrap around
      _chapter = 0;
      _wordIndexInChapter = 0;
      _loadCurrentWord();
      return;
    }
    setState(() {
      _currentWord = _allWords[globalIndex];
      _charStates = List.filled(_currentWord!.word.length, CharState.pending);
      _cursorIndex = 0;
    });
  }

  void _nextWord() {
    _wordIndexInChapter++;
    if (_wordIndexInChapter >= _wordsPerChapter) {
      _chapter++;
      _startChapter();
    } else {
      _loadCurrentWord();
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (_isPaused || _currentWord == null) return;

    final char = event.character;
    if (char == null || char.isEmpty) return;

    // only handle printable ascii letters
    final lower = char.toLowerCase();
    if (lower.length != 1 || lower.codeUnitAt(0) < 97 || lower.codeUnitAt(0) > 122) {
      // space to skip word
      if (char == ' ') {
        _nextWord();
      }
      return;
    }

    if (_cursorIndex >= _currentWord!.word.length) return;

    setState(() {
      _totalTyped++;
      if (lower == _currentWord!.word[_cursorIndex].toLowerCase()) {
        _charStates[_cursorIndex] = CharState.correct;
        _correctCount++;
      } else {
        _charStates[_cursorIndex] = CharState.wrong;
      }
      _cursorIndex++;
    });

    // word completed
    if (_cursorIndex >= _currentWord!.word.length) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _nextWord();
      });
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _toggleShuffle() {
    setState(() => _shuffle = !_shuffle);
  }

  void _toggleMeaning() {
    setState(() => _showMeaning = !_showMeaning);
  }

  String get _timeStr {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _wpm {
    if (_elapsedSeconds == 0) return 0;
    return (_totalTyped / (_elapsedSeconds / 60)).round();
  }

  String get _accuracyStr {
    if (_totalTyped == 0) return '0';
    return ((_correctCount / _totalTyped) * 100).round().toString();
  }

  int get _totalChapters => (_allWords.length / _wordsPerChapter).ceil();

  double get _chapterProgress {
    if (_wordsPerChapter == 0) return 0;
    return (_wordIndexInChapter + (_currentWord != null ? _cursorIndex / _currentWord!.word.length : 0)) / _wordsPerChapter;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: const Color(0xFF1A1B2E),
          child: _isLoaded ? _buildContent() : const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final word = _currentWord;
    if (word == null) return const SizedBox();

    return Column(
      children: [
        // Top bar
        _buildTopBar(),
        // Main content area
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Word display
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < word.word.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          word.word[i],
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 48,
                            fontWeight: FontWeight.w400,
                            color: _charColor(i),
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.volume_up,
                      color: Colors.grey.shade500,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Meaning
                if (_showMeaning)
                  Text(
                    word.meaning,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade300,
                    ),
                  ),
                const SizedBox(height: 32),
                // Progress bar
                SizedBox(
                  width: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _chapterProgress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF667EEA),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Stats panel
        _buildStatsPanel(),
        const SizedBox(height: 32),
      ],
    );
  }

  Color _charColor(int index) {
    if (index >= _charStates.length) return Colors.grey.shade600;
    switch (_charStates[index]) {
      case CharState.pending:
        return Colors.grey.shade500;
      case CharState.correct:
        return Colors.greenAccent;
      case CharState.wrong:
        return Colors.redAccent;
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CET-4 第 ${_chapter + 1} 章',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Text(
                  '美音',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                const SizedBox(width: 12),
                _iconBtn(Icons.volume_up, null),
                _iconBtn(
                  Icons.shuffle,
                  _toggleShuffle,
                  active: _shuffle,
                ),
                _iconBtn(
                  Icons.visibility,
                  _toggleMeaning,
                  active: _showMeaning,
                ),
                _iconBtn(Icons.dark_mode, null),
                _iconBtn(Icons.settings, null),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _togglePause,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  child: Text(_isPaused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.fullscreen, color: Colors.grey.shade400, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: Icon(
          icon,
          size: 18,
          color: active ? const Color(0xFF667EEA) : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 120),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(_timeStr, '时间'),
          _statDivider(),
          _statItem('$_totalTyped', '输入数'),
          _statDivider(),
          _statItem('$_wpm', 'WPM'),
          _statDivider(),
          _statItem('$_correctCount', '正确数'),
          _statDivider(),
          _statItem(_accuracyStr, '正确率'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF667EEA),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: 1,
          color: Colors.grey.shade700,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return const SizedBox(width: 24);
  }
}
