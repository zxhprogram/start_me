import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final String location;
  final WeatherCurrent current;
  final List<WeatherHourly> hourly;
  final List<WeatherDaily> daily;
  final String tip;

  WeatherData({
    required this.location,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.tip,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      location: json['location'] ?? '',
      current: WeatherCurrent.fromJson(json['current'] ?? {}),
      hourly: (json['hourly'] as List? ?? [])
          .map((e) => WeatherHourly.fromJson(e))
          .toList(),
      daily: (json['daily'] as List? ?? [])
          .map((e) => WeatherDaily.fromJson(e))
          .toList(),
      tip: json['tip'] ?? '',
    );
  }
}

class WeatherCurrent {
  final double temp;
  final int humidity;
  final int weatherCode;
  final String weather;
  final String weatherIcon;
  final double windSpeed;
  final String windDir;
  final String windLevel;
  final double pressure;
  final double precip;
  final int aqi;
  final String aqiLevel;
  final String time;

  WeatherCurrent({
    required this.temp,
    required this.humidity,
    required this.weatherCode,
    required this.weather,
    required this.weatherIcon,
    required this.windSpeed,
    required this.windDir,
    required this.windLevel,
    required this.pressure,
    required this.precip,
    required this.aqi,
    required this.aqiLevel,
    required this.time,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic> json) {
    return WeatherCurrent(
      temp: (json['temp'] ?? 0).toDouble(),
      humidity: json['humidity'] ?? 0,
      weatherCode: json['weather_code'] ?? 0,
      weather: json['weather'] ?? '',
      weatherIcon: json['weather_icon'] ?? 'cloud',
      windSpeed: (json['wind_speed'] ?? 0).toDouble(),
      windDir: json['wind_dir'] ?? '',
      windLevel: json['wind_level'] ?? '',
      pressure: (json['pressure'] ?? 0).toDouble(),
      precip: (json['precip'] ?? 0).toDouble(),
      aqi: json['aqi'] ?? 0,
      aqiLevel: json['aqi_level'] ?? '',
      time: json['time'] ?? '',
    );
  }
}

class WeatherHourly {
  final String time;
  final String hour;
  final double temp;
  final int weatherCode;
  final String weather;
  final String weatherIcon;

  WeatherHourly({
    required this.time,
    required this.hour,
    required this.temp,
    required this.weatherCode,
    required this.weather,
    required this.weatherIcon,
  });

  factory WeatherHourly.fromJson(Map<String, dynamic> json) {
    return WeatherHourly(
      time: json['time'] ?? '',
      hour: json['hour'] ?? '',
      temp: (json['temp'] ?? 0).toDouble(),
      weatherCode: json['weather_code'] ?? 0,
      weather: json['weather'] ?? '',
      weatherIcon: json['weather_icon'] ?? 'cloud',
    );
  }
}

class WeatherDaily {
  final String date;
  final String dayOfWeek;
  final int weatherCode;
  final String weather;
  final String weatherIcon;
  final double tempMax;
  final double tempMin;
  final String sunrise;
  final String sunset;

  WeatherDaily({
    required this.date,
    required this.dayOfWeek,
    required this.weatherCode,
    required this.weather,
    required this.weatherIcon,
    required this.tempMax,
    required this.tempMin,
    required this.sunrise,
    required this.sunset,
  });

  factory WeatherDaily.fromJson(Map<String, dynamic> json) {
    return WeatherDaily(
      date: json['date'] ?? '',
      dayOfWeek: json['day_of_week'] ?? '',
      weatherCode: json['weather_code'] ?? 0,
      weather: json['weather'] ?? '',
      weatherIcon: json['weather_icon'] ?? 'cloud',
      tempMax: (json['temp_max'] ?? 0).toDouble(),
      tempMin: (json['temp_min'] ?? 0).toDouble(),
      sunrise: json['sunrise'] ?? '',
      sunset: json['sunset'] ?? '',
    );
  }
}

class CitySearchResult {
  final String name;
  final String country;
  final String admin1;
  final double lat;
  final double lon;

  CitySearchResult({
    required this.name,
    required this.country,
    required this.admin1,
    required this.lat,
    required this.lon,
  });

  factory CitySearchResult.fromJson(Map<String, dynamic> json) {
    return CitySearchResult(
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      admin1: json['admin1'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
    );
  }
}

class WeatherService {
  static const String _baseUrl = 'http://localhost:8080/api';

  static Future<WeatherData?> fetchWeather({
    double lat = 39.8585,
    double lon = 116.2867,
    String location = '北京市·丰台',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/weather?lat=$lat&lon=$lon&location=$location'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return WeatherData.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching weather: $e');
      return null;
    }
  }

  static Future<List<CitySearchResult>> searchCity(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/weather/search?q=$query'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((e) => CitySearchResult.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching city: $e');
      return [];
    }
  }
}
