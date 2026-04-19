import 'package:flutter/material.dart';
import '../services/keystroke_service.dart';

class KeyboardStatsDialog extends StatefulWidget {
  const KeyboardStatsDialog({super.key});

  @override
  State<KeyboardStatsDialog> createState() => _KeyboardStatsDialogState();
}

class _KeyboardStatsDialogState extends State<KeyboardStatsDialog> {
  Map<String, int> _keyCounts = {};
  List<String> _dates = [];
  String _selectedDate = '';
  bool _isLoading = true;
  int _dateIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({String? date}) async {
    setState(() => _isLoading = true);
    final result = await KeystrokeService.getAllKeys(date: date);
    if (mounted) {
      setState(() {
        _keyCounts = Map<String, int>.from(result['data'] as Map);
        _selectedDate = result['date'] as String;
        _dates = List<String>.from(result['dates'] as List);
        if (_dates.isNotEmpty) {
          _dateIndex = _dates.indexOf(_selectedDate);
          if (_dateIndex < 0) _dateIndex = 0;
        }
        _isLoading = false;
      });
    }
  }

  void _prevDate() {
    if (_dateIndex < _dates.length - 1) {
      _dateIndex++;
      _loadData(date: _dates[_dateIndex]);
    }
  }

  void _nextDate() {
    if (_dateIndex > 0) {
      _dateIndex--;
      _loadData(date: _dates[_dateIndex]);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              surface: Color(0xFF2D2D3A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final dateStr =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _loadData(date: dateStr);
    }
  }

  int get _maxCount {
    if (_keyCounts.isEmpty) return 1;
    return _keyCounts.values.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 920,
          height: 500,
          color: const Color(0xFF1A1A2E),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white54))
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: _buildKeyboard(),
                      ),
              ),
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
          const Icon(Icons.keyboard_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text(
            '按键统计',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _buildDateSelector(),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final canPrev = _dateIndex < _dates.length - 1;
    final canNext = _dateIndex > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: canPrev ? Colors.white70 : Colors.white24, size: 20),
            onPressed: canPrev ? _prevDate : null,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          GestureDetector(
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _selectedDate.isNotEmpty ? _selectedDate : '今天',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: canNext ? Colors.white70 : Colors.white24, size: 20),
            onPressed: canNext ? _nextDate : null,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard() {
    return Column(
      children: [
        _buildRow(_row1),
        const SizedBox(height: 6),
        _buildRow(_row2),
        const SizedBox(height: 6),
        _buildRow(_row3),
        const SizedBox(height: 6),
        _buildRow(_row4),
        const SizedBox(height: 6),
        _buildRow(_row5),
      ],
    );
  }

  Widget _buildRow(List<_KeyDef> keys) {
    return Expanded(
      child: Row(
        children: keys.map((k) {
          if (k == keys.last) return Expanded(flex: k.flex, child: _buildKey(k));
          return Expanded(
            flex: k.flex,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildKey(k),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKey(_KeyDef key) {
    final count = _keyCounts[key.dataKey] ?? 0;
    final ratio = _maxCount > 0 ? count / _maxCount : 0.0;

    final baseColor = const Color(0xFF2D2D3A);
    final hotColor = const Color(0xFF4A6CF7);
    final bgColor = count > 0
        ? Color.lerp(baseColor, hotColor, ratio * 0.8)!
        : baseColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: count > 0
              ? hotColor.withOpacity(0.3 + ratio * 0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              key.label,
              style: TextStyle(
                color: count > 0 ? Colors.white : Colors.white54,
                fontSize: key.fontSize,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (count > 0)
            Positioned(
              top: 2,
              right: 4,
              child: Text(
                _formatCount(count),
                style: TextStyle(
                  color: Colors.orangeAccent.withOpacity(0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 1000).toStringAsFixed(1)}k';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

class _KeyDef {
  final String label;
  final String dataKey;
  final int flex;
  final double fontSize;

  const _KeyDef(this.label, this.dataKey, {this.flex = 10, this.fontSize = 12});
}

final _row1 = [
  const _KeyDef('`', '`'),
  const _KeyDef('1', '1'),
  const _KeyDef('2', '2'),
  const _KeyDef('3', '3'),
  const _KeyDef('4', '4'),
  const _KeyDef('5', '5'),
  const _KeyDef('6', '6'),
  const _KeyDef('7', '7'),
  const _KeyDef('8', '8'),
  const _KeyDef('9', '9'),
  const _KeyDef('0', '0'),
  const _KeyDef('-', '-'),
  const _KeyDef('=', '='),
  const _KeyDef('⌫', 'Backspace', flex: 18, fontSize: 11),
];

final _row2 = [
  const _KeyDef('Tab', 'Tab', flex: 15, fontSize: 11),
  const _KeyDef('Q', 'Q'),
  const _KeyDef('W', 'W'),
  const _KeyDef('E', 'E'),
  const _KeyDef('R', 'R'),
  const _KeyDef('T', 'T'),
  const _KeyDef('Y', 'Y'),
  const _KeyDef('U', 'U'),
  const _KeyDef('I', 'I'),
  const _KeyDef('O', 'O'),
  const _KeyDef('P', 'P'),
  const _KeyDef('[', '['),
  const _KeyDef(']', ']'),
  const _KeyDef('\\', '\\', flex: 13),
];

final _row3 = [
  const _KeyDef('Caps', 'CapsLock', flex: 18, fontSize: 11),
  const _KeyDef('A', 'A'),
  const _KeyDef('S', 'S'),
  const _KeyDef('D', 'D'),
  const _KeyDef('F', 'F'),
  const _KeyDef('G', 'G'),
  const _KeyDef('H', 'H'),
  const _KeyDef('J', 'J'),
  const _KeyDef('K', 'K'),
  const _KeyDef('L', 'L'),
  const _KeyDef(';', ';'),
  const _KeyDef("'", "'"),
  const _KeyDef('Enter', 'Enter', flex: 20, fontSize: 11),
];

final _row4 = [
  const _KeyDef('Shift', 'LShift', flex: 23, fontSize: 11),
  const _KeyDef('Z', 'Z'),
  const _KeyDef('X', 'X'),
  const _KeyDef('C', 'C'),
  const _KeyDef('V', 'V'),
  const _KeyDef('B', 'B'),
  const _KeyDef('N', 'N'),
  const _KeyDef('M', 'M'),
  const _KeyDef(',', ','),
  const _KeyDef('.', '.'),
  const _KeyDef('/', '/'),
  const _KeyDef('Shift', 'RShift', flex: 25, fontSize: 11),
];

final _row5 = [
  const _KeyDef('Ctrl', 'LCtrl', flex: 14, fontSize: 11),
  const _KeyDef('Win', 'Win', flex: 12, fontSize: 11),
  const _KeyDef('Alt', 'LAlt', flex: 12, fontSize: 11),
  const _KeyDef('Space', 'Space', flex: 60, fontSize: 11),
  const _KeyDef('Alt', 'RAlt', flex: 12, fontSize: 11),
  const _KeyDef('Ctrl', 'RCtrl', flex: 14, fontSize: 11),
];
