import 'dart:math';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../signals/app_signal.dart';
import '../services/weather_service.dart';

class WeatherDetailDialog extends StatefulWidget {
  final VoidCallback onClose;

  const WeatherDetailDialog({super.key, required this.onClose});

  @override
  State<WeatherDetailDialog> createState() => _WeatherDetailDialogState();
}

class _WeatherDetailDialogState extends State<WeatherDetailDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<CitySearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isRefreshing = false;

  Future<void> _searchCity() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await WeatherService.searchCity(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectCity(CitySearchResult city) async {
    setState(() {
      _searchResults = [];
      _searchController.clear();
      _isRefreshing = true;
    });

    final name = '${city.admin1}·${city.name}';
    weatherLocation.value = {
      'lat': city.lat,
      'lon': city.lon,
      'name': name,
    };

    final data = await WeatherService.fetchWeather(
      lat: city.lat,
      lon: city.lon,
      location: name,
    );
    if (data != null) {
      fullWeatherData.value = data;
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final loc = weatherLocation.value;
    final data = await WeatherService.fetchWeather(
      lat: (loc['lat'] as num).toDouble(),
      lon: (loc['lon'] as num).toDouble(),
      location: loc['name'] as String,
    );
    if (data != null) {
      fullWeatherData.value = data;
    }
    if (mounted) setState(() => _isRefreshing = false);
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

  String _formatTime(String time) {
    // "2026-04-18T00:23" -> "04-18 00:23"
    if (time.length >= 16) {
      return '${time.substring(5, 10)} ${time.substring(11, 16)}';
    }
    return time;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Watch((context) {
        final weather = fullWeatherData.value;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 1100,
            height: 700,
            color: const Color(0xFF2A2A3A),
            child: weather == null || _isRefreshing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white70))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(weather),
                        const SizedBox(height: 24),
                        _buildCurrentWeather(weather),
                        const SizedBox(height: 20),
                        _buildTipAndDetails(weather),
                        const SizedBox(height: 28),
                        _buildHourlyForecast(weather),
                        const SizedBox(height: 28),
                        _buildDailyForecast(weather),
                      ],
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(WeatherData weather) {
    return Row(
      children: [
        // City + weather + time
        Expanded(
          child: Text(
            '${weather.location}  ${weather.current.weather}    发布于:${_formatTime(weather.current.time)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        // Search box
        Container(
          width: 200,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '输入城市、乡镇',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _searchCity(),
                ),
              ),
              GestureDetector(
                onTap: _searchCity,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white54))
                      : Icon(Icons.search,
                          color: Colors.white.withOpacity(0.5), size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Refresh
        GestureDetector(
          onTap: _refresh,
          child: Icon(Icons.refresh,
              color: Colors.white.withOpacity(0.5), size: 20),
        ),
        const SizedBox(width: 8),
        // Close
        GestureDetector(
          onTap: widget.onClose,
          child: Icon(Icons.close,
              color: Colors.white.withOpacity(0.5), size: 20),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A4A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _searchResults.take(6).map((city) {
          return GestureDetector(
            onTap: () => _selectCity(city),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${city.name}, ${city.admin1}, ${city.country}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentWeather(WeatherData weather) {
    final current = weather.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchResults.isNotEmpty) _buildSearchResults(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large temperature
            Text(
              '${current.temp.round()}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w200,
                height: 1,
              ),
            ),
            const SizedBox(width: 24),
            // AQI + weather + wind
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: Colors.white.withOpacity(0.7), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${current.aqiLevel}/${current.aqi}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(_getIconData(current.weatherIcon),
                        color: Colors.white.withOpacity(0.7), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${current.weather}  ${current.windDir}  ${current.windLevel}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipAndDetails(WeatherData weather) {
    final current = weather.current;
    final today = weather.daily.isNotEmpty ? weather.daily[0] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          weather.tip,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 6,
          children: [
            if (today != null)
              _detailItem('温度 ${today.tempMin.round()}~${today.tempMax.round()}°'),
            _detailItem('湿度 ${current.humidity}%'),
            _detailItem('气压 ${current.pressure.round()}hPa'),
            _detailItem('降水 ${current.precip}mm'),
            if (today != null) _detailItem('日出 ${today.sunrise}'),
            if (today != null) _detailItem('日落 ${today.sunset}'),
          ],
        ),
      ],
    );
  }

  Widget _detailItem(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 13,
      ),
    );
  }

  Widget _buildHourlyForecast(WeatherData weather) {
    final hourly = weather.hourly;
    if (hourly.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time,
                color: Colors.white.withOpacity(0.5), size: 16),
            const SizedBox(width: 6),
            Text(
              '24小时天气预报',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: hourly.length * 65.0,
              child: CustomPaint(
                painter: _HourlyChartPainter(hourly, _getIconData),
                child: Column(
                  children: [
                    // Hour labels
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: hourly.map((h) {
                          return SizedBox(
                            width: 65,
                            child: Center(
                              child: Text(
                                h.hour,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Icons
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 24,
                      child: Row(
                        children: hourly.map((h) {
                          return SizedBox(
                            width: 65,
                            child: Center(
                              child: Icon(
                                _getIconData(h.weatherIcon),
                                color: Colors.white.withOpacity(0.6),
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Space for chart + temp labels
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyForecast(WeatherData weather) {
    final daily = weather.daily;
    if (daily.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today,
                color: Colors.white.withOpacity(0.5), size: 16),
            const SizedBox(width: 6),
            Text(
              '7日天气预报',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: daily.length,
            itemBuilder: (context, index) {
              final day = daily[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      day.dayOfWeek,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      day.date,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getIconData(day.weatherIcon),
                            color: Colors.white.withOpacity(0.6), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          day.weather,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${day.tempMin.round()}° / ${day.tempMax.round()}°',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HourlyChartPainter extends CustomPainter {
  final List<WeatherHourly> hourly;
  final IconData Function(String) getIconData;

  _HourlyChartPainter(this.hourly, this.getIconData);

  @override
  void paint(Canvas canvas, Size size) {
    if (hourly.isEmpty) return;

    final temps = hourly.map((h) => h.temp).toList();
    final minTemp = temps.reduce(min);
    final maxTemp = temps.reduce(max);
    final range = maxTemp - minTemp;

    // Chart area: below icons (top 50px), above bottom
    const topOffset = 60.0;
    final chartHeight = size.height - topOffset - 30;
    final itemWidth = 65.0;

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.6),
      fontSize: 11,
    );

    final points = <Offset>[];

    for (int i = 0; i < hourly.length; i++) {
      final x = i * itemWidth + itemWidth / 2;
      final normalizedTemp = range > 0 ? (hourly[i].temp - minTemp) / range : 0.5;
      final y = topOffset + chartHeight * (1 - normalizedTemp);
      points.add(Offset(x, y));
    }

    // Draw line
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw dots and temp labels
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, 3, dotPaint);

      // Temperature label above dot
      final textSpan = TextSpan(
        text: '${hourly[i].temp.round()}°',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(p.dx - textPainter.width / 2, p.dy - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
