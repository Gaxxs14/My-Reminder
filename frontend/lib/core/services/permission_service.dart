import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  /// Prompt all core app permissions gracefully on app startup or onboarding
  Future<Map<Permission, PermissionStatus>> requestInitialPermissions() async {
    final statuses = await [
      Permission.notification,
      Permission.locationWhenInUse,
    ].request();

    return statuses;
  }

  /// Request Camera & Storage permission for OCR or Profile picture
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request Microphone permission for Voice Assistant
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request Location permission for Weather & geotagging
  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Request Notification permission for alarms & reminders
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
