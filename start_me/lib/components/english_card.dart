import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';

class EnglishCard extends StatelessWidget {
  const EnglishCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final quote = englishQuote.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?w=400&h=300&fit=crop',
            ),
            fit: BoxFit.cover,
            opacity: 0.3,
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
                      Text(
                        '跟读',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                      Icon(Icons.play_arrow, color: Colors.white70, size: 14),
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
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const Spacer(),
          ],
        ),
      );
    });
  }
}
