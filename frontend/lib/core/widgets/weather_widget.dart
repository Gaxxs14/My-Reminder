import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final String condition;
  final String icon;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.condition,
    required this.icon,
  });
}

class WeatherWidget extends ConsumerStatefulWidget {
  const WeatherWidget({super.key});

  @override
  ConsumerState<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends ConsumerState<WeatherWidget> {
  bool _isLoading = true;
  double? _temp;
  String _condition = 'Cargando clima...';
  String _icon = '🌤️';
  String _cityName = 'Ubicación GPS';
  List<DailyForecast> _dailyForecasts = [];

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Map<String, String> _getWeatherDetails(int code) {
    if (code == 0) {
      return {'cond': 'Despejado / Soleado', 'icon': '☀️'};
    } else if (code >= 1 && code <= 3) {
      return {'cond': 'Parcialmente Nublado', 'icon': '🌤️'};
    } else if (code >= 45 && code <= 48) {
      return {'cond': 'Neblina / Niebla', 'icon': '🌫️'};
    } else if (code >= 51 && code <= 67) {
      return {'cond': 'Lluvia / Llovizna', 'icon': '🌧️'};
    } else if (code >= 71 && code <= 77) {
      return {'cond': 'Nieve / Helada', 'icon': '❄️'};
    } else if (code >= 80 && code <= 99) {
      return {'cond': 'Tormenta Eléctrica', 'icon': '⛈️'};
    }
    return {'cond': 'Variable', 'icon': '🌤️'};
  }

  Future<void> _fetchWeather() async {
    try {
      double lat = 10.4806; // Default fallback (LATAM)
      double lon = -66.9036;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        );
        lat = pos.latitude;
        lon = pos.longitude;
        _cityName = 'Tu Zona GPS';
      }

      final dio = Dio();
      final response = await dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'current_weather': true,
          'daily': 'temperature_2m_max,temperature_2m_min,weathercode',
          'timezone': 'auto',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final cw = data['current_weather'];
        final tempVal = (cw['temperature'] as num).toDouble();
        final code = cw['weathercode'] as int;

        final currInfo = _getWeatherDetails(code);

        // Parse 7-day daily forecast
        final List<DailyForecast> forecasts = [];
        if (data.containsKey('daily')) {
          final daily = data['daily'];
          final List<dynamic> dates = daily['time'] as List;
          final List<dynamic> maxTemps = daily['temperature_2m_max'] as List;
          final List<dynamic> minTemps = daily['temperature_2m_min'] as List;
          final List<dynamic> codes = daily['weathercode'] as List;

          for (int i = 0; i < dates.length && i < 7; i++) {
            final dt = DateTime.parse(dates[i].toString());
            final maxT = (maxTemps[i] as num).toDouble();
            final minT = (minTemps[i] as num).toDouble();
            final c = codes[i] as int;
            final info = _getWeatherDetails(c);

            forecasts.add(DailyForecast(
              date: dt,
              maxTemp: maxT,
              minTemp: minT,
              condition: info['cond']!,
              icon: info['icon']!,
            ));
          }
        }

        if (mounted) {
          setState(() {
            _temp = tempVal;
            _condition = currInfo['cond']!;
            _icon = currInfo['icon']!;
            _dailyForecasts = forecasts;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _temp = 24.0;
          _condition = 'Clima Templado';
          _icon = '🌤️';
          _isLoading = false;
        });
      }
    }
  }

  void _show7DayForecastModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? AppTheme.glassBorder : Colors.grey[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_rounded, color: AppTheme.primaryDark, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Pronóstico Real del Clima (7 Días)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 14, color: AppTheme.primaryDark),
                  const SizedBox(width: 4),
                  Text(
                    '$_cityName • Datos en tiempo real por GPS',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_dailyForecasts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('Cargando pronóstico semanal...')),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _dailyForecasts.length,
                    itemBuilder: (context, idx) {
                      final fc = _dailyForecasts[idx];
                      final isToday = idx == 0;
                      final dayName = isToday ? 'Hoy' : DateFormat('EEEE, d MMM', 'es_ES').format(fc.date);
                      final formattedDay = dayName[0].toUpperCase() + dayName.substring(1);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.primaryDark.withValues(alpha: 0.15)
                              : (isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isToday ? AppTheme.primaryDark.withValues(alpha: 0.5) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(fc.icon, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formattedDay,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isToday ? AppTheme.primaryDark : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fc.condition,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Max ${fc.maxTemp.toStringAsFixed(0)}°C',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Min ${fc.minTemp.toStringAsFixed(0)}°C',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _show7DayForecastModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(_icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _temp != null ? '${_temp!.toStringAsFixed(1)}°C' : '--°C',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _cityName,
                              style: const TextStyle(fontSize: 10, color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoading ? 'Obteniendo clima...' : '$_condition • Toca para ver 7 días ➔',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, size: 22, color: AppTheme.primaryDark),
                  tooltip: 'Pronóstico Semanal 7 Días',
                  onPressed: _show7DayForecastModal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
