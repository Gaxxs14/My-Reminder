import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize timezone database (required for scheduled notifications)
    tz.initializeTimeZones();
    
    // 2. Configure Android settings (using default launcher icon)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Configure iOS / Darwin settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. Combine settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 5. Initialize plugin
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle clicking on notification if needed
      },
    );
  }

  // Request permissions for Android 13+
  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
        
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  // Schedule a local alarm
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Don't schedule if date is in the past
    if (scheduledTime.isBefore(DateTime.now())) return;

    final int intId = id.hashCode; // Map String UUID to unique int for system alarm

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'my_reminder_channel_id',
      'Alertas de Recordatorios',
      channelDescription: 'Canal de notificaciones para las alarmas de tus tareas.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notificationsPlugin.zonedSchedule(
      intId,
      title,
      body,
      tzTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Show an instant local notification
  Future<void> showInstantNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    final int intId = id.hashCode;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'my_reminder_geo_channel_id',
      'Alertas Geográficas',
      channelDescription: 'Canal de notificaciones para las alarmas por ubicación.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      intId,
      title,
      body,
      platformDetails,
    );
  }

  // Cancel a scheduled alarm
  Future<void> cancelNotification(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
  }

  // Clear all pending alarms
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
