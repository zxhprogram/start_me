import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';

// 背景图片 URL
const String _backgroundImage = 'https://staticedu-wps-cache.iciba.com/image/c0ccd572fce797d9c288990d7e38ba94.png';

class EnglishCard extends StatefulWidget {
  const EnglishCard({super.key});

  @override
  State<EnglishCard> createState() => _EnglishCardState();
}

class _EnglishCardState extends State<EnglishCard> {
  bool _isPlaying = false;

  void _showPracticeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: PracticeDialog(
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final quote = englishQuote.value;

      return GestureDetector(
        onTap: _showPracticeDialog,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: NetworkImage(_backgroundImage),
              fit: BoxFit.cover,
              opacity: 0.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '跟读',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // English quote
              Text(
                quote['en']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // Chinese translation
              Text(
                quote['cn']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      );
    });
  }
}

class PracticeDialog extends StatefulWidget {
  final VoidCallback onClose;

  const PracticeDialog({super.key, required this.onClose});

  @override
  State<PracticeDialog> createState() => _PracticeDialogState();
}

class _PracticeDialogState extends State<PracticeDialog> {
  bool _isPlaying = false;
  bool _isCompleted = false;

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _completePractice() {
    setState(() {
      _isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 800,
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage(_backgroundImage),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white30,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // English text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Text(
              'Hope is the feather that balances the stone of today.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w500,
                height: 1.6,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Chinese translation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Text(
              '希望是那根羽毛，平衡着今日的石块。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.5,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Play button
          Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: GestureDetector(
              onTap: _isCompleted ? null : _togglePlay,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _isCompleted
                      ? Colors.green.withOpacity(0.8)
                      : Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isCompleted ? Colors.green : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isCompleted ? Icons.check : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
