import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/global_providers.dart';
import '../../features/reminders/presentation/reminders_provider.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref);
});

class LocationService {
  final Ref _ref;
  StreamSubscription<Position>? _positionStreamSubscription;

  LocationService(this._ref);

  // Request GPS Permissions and return check status
  Future<bool> handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Start continuous tracking of position for geographical reminders
  Future<void> startTracking() async {
    final hasPermission = await handlePermission();
    if (!hasPermission) return;

    // Check location settings
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Fire stream updates only when moved 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _checkGeoReminders(position);
    });
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // Check distance to all pending reminders
  void _checkGeoReminders(Position position) async {
    final reminders = _ref.read(remindersProvider);
    final notificationService = _ref.read(notificationServiceProvider);

    for (final reminder in reminders) {
      if (reminder.status == 'pending' &&
          reminder.latitude != null &&
          reminder.longitude != null) {
        
        final double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          reminder.latitude!,
          reminder.longitude!,
        );

        final radius = reminder.radiusInMeters ?? 150.0;

        if (distanceInMeters <= radius) {
          // Trigger local physical notification
          await notificationService.showInstantNotification(
            id: reminder.id,
            title: '📍 ¡Llegaste a tu destino!',
            body: 'Recuerda: ${reminder.title} en ${reminder.locationName ?? "esta zona"}.',
          );

          // Mark reminder as completed locally & cloud
          await _ref.read(remindersProvider.notifier).toggleReminderStatus(reminder.id);
        }
      }
    }
  }
}
