import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/weather_service.dart';
import 'weather_detail_dialog.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (fullWeatherData.value == null) {
      _loadWeather();
    }
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoading = true);
    final loc = weatherLocation.value;
    final data = await WeatherService.fetchWeather(
      lat: (loc['lat'] as num).toDouble(),
      lon: (loc['lon'] as num).toDouble(),
      location: loc['name'] as String,
    );
    if (data != null) {
      fullWeatherData.value = data;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _openDetailDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WeatherDetailDialog(
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'partly_cloudy':
        return Icons.cloud_queue;
      case 'cloud':
        return Icons.cloud;
      case 'foggy':
        return Icons.foggy;
      case 'grain':
        return Icons.grain;
      case 'water_drop':
        return Icons.water_drop;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.flash_on;
      default:
        return Icons.cloud;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final weather = fullWeatherData.value;

      return GestureDetector(
        onTap: _openDetailDialog,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaleFactor = (constraints.maxHeight / 200).clamp(0.6, 1.0);

            if (weather == null) {
              return Container(
                padding: EdgeInsets.all(16 * scaleFactor),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A4A6B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white70)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off,
                                color: Colors.white.withOpacity(0.5), size: 36),
                            const SizedBox(height: 8),
                            Text('加载天气数据...',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13)),
                          ],
                        ),
                ),
              );
            }

            final current = weather.current;
            final daily = weather.daily;

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
                        weather.location,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14 * scaleFactor,
                        ),
                      ),
                      SizedBox(width: 4 * scaleFactor),
                      Icon(Icons.location_on,
                          color: Colors.white70, size: 14 * scaleFactor),
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
                            '${current.temp.round()}°',
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
                          Icon(_getIconData(current.weatherIcon),
                              color: Colors.white70, size: 28 * scaleFactor),
                          SizedBox(height: 2 * scaleFactor),
                          Text(
                            current.weather,
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

                  // Low/High from today's daily
                  if (daily.isNotEmpty)
                    Text(
                      '最低 ${daily[0].tempMin.round()}° 最高 ${daily[0].tempMax.round()}°',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11 * scaleFactor,
                      ),
                    ),

                  const Spacer(),

                  // Forecast
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: daily.take(6).map((day) {
                      return Expanded(
                        child: _ForecastDay(
                          day: day.dayOfWeek,
                          icon: _getIconData(day.weatherIcon),
                          low: day.tempMin.round(),
                          high: day.tempMax.round(),
                          scaleFactor: scaleFactor,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
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
