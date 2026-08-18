import 'package:flutter_tts/flutter_tts.dart';
import '../../features/reminders/data/local_reminder_repository.dart';
import '../../features/habits/data/local_habit_repository.dart';
import '../security/secure_storage_service.dart';

class MulanBriefingService {
  final LocalReminderRepository _reminderRepo;
  final LocalHabitRepository _habitRepo;
  final SecureStorageService _secureStorage;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  MulanBriefingService({
    required LocalReminderRepository reminderRepo,
    required LocalHabitRepository habitRepo,
    required SecureStorageService secureStorage,
  })  : _reminderRepo = reminderRepo,
        _habitRepo = habitRepo,
        _secureStorage = secureStorage {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('es-US');
    await _flutterTts.setPitch(1.05);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  bool get isSpeaking => _isSpeaking;

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// Genera y reproduce el saludo hablado inteligente de Mulan al entrar a la app
  Future<String> playLoginBriefing({bool force = false}) async {
    final username = await _secureStorage.getUsername() ?? 'amigo';
    final now = DateTime.now();

    // Determinar saludo según la hora del día
    String timeGreeting = '¡Buenos días';
    if (now.hour >= 12 && now.hour < 19) {
      timeGreeting = '¡Buenas tardes';
    } else if (now.hour >= 19 || now.hour < 5) {
      timeGreeting = '¡Buenas noches';
    }

    try {
      // 1. Obtener recordatorios de hoy
      final allReminders = await _reminderRepo.getReminders();
      final todayReminders = allReminders.where((r) {
        if (r.status == 'completed') return false;
        final d = r.dueDate;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      // 2. Obtener hábitos pendientes
      final allHabits = await _habitRepo.getHabits();
      final pendingHabits = allHabits.where((h) {
        if (h.lastCompleted == null) return true;
        final d = h.lastCompleted!;
        return !(d.year == now.year && d.month == now.month && d.day == now.day);
      }).toList();

      // 3. Construir mensaje personalizado
      final buffer = StringBuffer();
      buffer.write('$timeGreeting, $username! Soy Mulan. ');

      if (todayReminders.isEmpty && pendingHabits.isEmpty) {
        buffer.write('Tu agenda está totalmente despejada y al día. ¡Es un gran momento para avanzar o relajarte!');
      } else {
        if (todayReminders.isNotEmpty) {
          final count = todayReminders.length;
          final nextOne = todayReminders.first;
          buffer.write('Para hoy tienes $count ${count == 1 ? 'recordatorio' : 'recordatorios'}. El próximo es: "${nextOne.title}". ');
        } else {
          buffer.write('No tienes recordatorios pendientes para hoy. ');
        }

        if (pendingHabits.isNotEmpty) {
          final hCount = pendingHabits.length;
          buffer.write('Y te ${hCount == 1 ? 'falta cumplir 1 hábito' : 'faltan cumplir $hCount hábitos'} para mantener tu racha. ');
        } else {
          buffer.write('¡Ya completaste todos tus hábitos de hoy! ');
        }

        buffer.write('¡Estoy lista para ayudarte cuando lo necesites!');
      }

      final speechText = buffer.toString();
      _isSpeaking = true;
      await _flutterTts.speak(speechText);
      return speechText;
    } catch (e) {
      final fallbackText = '$timeGreeting, $username! Me alegra verte. Estoy lista para ayudarte con tus recordatorios y hábitos.';
      _isSpeaking = true;
      await _flutterTts.speak(fallbackText);
      return fallbackText;
    }
  }
}
