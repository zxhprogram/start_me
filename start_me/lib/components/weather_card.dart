import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final weather = weatherData.value;
      final forecast = weather['forecast'] as List;

      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate scale factor based on available height
          final scaleFactor = (constraints.maxHeight / 200).clamp(0.6, 1.0);

          return Container(
            padding: EdgeInsets.all(16 * scaleFactor),
            decoration: BoxDecoration(
              color: const Color(0xFF3A4A6B).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Row(
                  children: [
                    Text(
                      weather['location'],
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14 * scaleFactor,
                      ),
                    ),
                    SizedBox(width: 4 * scaleFactor),
                    Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 14 * scaleFactor,
                    ),
                  ],
                ),

                SizedBox(height: 8 * scaleFactor),

                // Temperature and condition
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${weather['temp']}°',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48 * scaleFactor,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud,
                          color: Colors.white70,
                          size: 28 * scaleFactor,
                        ),
                        SizedBox(height: 2 * scaleFactor),
                        Text(
                          weather['condition'],
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13 * scaleFactor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 4 * scaleFactor),

                // Low/High
                Text(
                  '最低 ${weather['low']}° 最高 ${weather['high']}°',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11 * scaleFactor,
                  ),
                ),

                const Spacer(),

                // Forecast - using Flexible to fit available space
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: forecast.take(6).map((day) {
                    return Expanded(
                      child: _ForecastDay(
                        day: day['day'],
                        icon: day['icon'],
                        low: day['low'],
                        high: day['high'],
                        scaleFactor: scaleFactor,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _ForecastDay extends StatelessWidget {
  final String day;
  final IconData icon;
  final int low;
  final int high;
  final double scaleFactor;

  const _ForecastDay({
    required this.day,
    required this.icon,
    required this.low,
    required this.high,
    required this.scaleFactor,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10 * scaleFactor,
            ),
          ),
          SizedBox(height: 2 * scaleFactor),
          Icon(icon, color: Colors.white70, size: 14 * scaleFactor),
          SizedBox(height: 2 * scaleFactor),
          Text(
            '$low~$high',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9 * scaleFactor,
            ),
          ),
        ],
      ),
    );
  }
}
