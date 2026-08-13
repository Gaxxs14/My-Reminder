import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../theme/app_theme.dart';

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
  String _cityName = 'Ubicación Actual';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      double lat = 10.4806; // Default fallback (Caracas/LATAM)
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
        },
      );

      if (response.statusCode == 200) {
        final cw = response.data['current_weather'];
        final tempVal = (cw['temperature'] as num).toDouble();
        final code = cw['weathercode'] as int;

        String cond = 'Despejado';
        String ico = '☀️';

        if (code == 0) {
          cond = 'Despejado / Soleado';
          ico = '☀️';
        } else if (code >= 1 && code <= 3) {
          cond = 'Parcialmente Nublado';
          ico = '🌤️';
        } else if (code >= 45 && code <= 48) {
          cond = 'Neblina';
          ico = '🌫️';
        } else if (code >= 51 && code <= 67) {
          cond = 'Lluvia Ligera';
          ico = '🌧️';
        } else if (code >= 80 && code <= 99) {
          cond = 'Tormenta / Torrencial';
          ico = '⛈️';
        }

        if (mounted) {
          setState(() {
            _temp = tempVal;
            _condition = cond;
            _icon = ico;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Row(
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
                  _isLoading ? 'Obteniendo clima...' : _condition,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchWeather();
            },
          ),
        ],
      ),
    );
  }
}
