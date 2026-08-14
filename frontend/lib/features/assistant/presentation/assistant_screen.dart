import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gaxxs_loader.dart';
import '../../reminders/data/reminder_model.dart';
import '../../reminders/presentation/reminders_provider.dart';

class MessageItem {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ReminderModel? createdReminder;

  MessageItem({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.createdReminder,
  }) : timestamp = timestamp ?? DateTime.now();
}

class VoiceOption {
  final String name;
  final String icon;
  final double pitch;
  final double rate;

  const VoiceOption({
    required this.name,
    required this.icon,
    required this.pitch,
    required this.rate,
  });
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSending = false;
  bool _isSpeakerEnabled = true;
  String _lastWords = '';

  double _currentPitch = 1.0;
  double _currentRate = 0.5;
  String _selectedVoiceName = 'Mulan (Femenina Cálida)';

  static const List<VoiceOption> _voiceOptions = [
    VoiceOption(name: 'Mulan (Femenina Cálida)', icon: '🌸', pitch: 1.0, rate: 0.5),
    VoiceOption(name: 'Femenina Dulce', icon: '🎀', pitch: 1.25, rate: 0.55),
    VoiceOption(name: 'Masculina Grave', icon: '🧔', pitch: 0.70, rate: 0.45),
    VoiceOption(name: 'Masculina Sobria', icon: '👨', pitch: 0.85, rate: 0.50),
    VoiceOption(name: 'Voz Rápida & Dinámica', icon: '⚡', pitch: 1.0, rate: 0.65),
  ];

  final List<MessageItem> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _loadVoicePreference();
    
    // Welcome message from Assistant
    _messages.add(
      MessageItem(
        text: '¡Hola! Soy tu asistente de My Reminder. Toca el micrófono para hablar o escribe tu mensaje abajo. Puedo responder tus dudas sobre la app o agendar tus tareas en tu Agenda.',
        isUser: false,
      ),
    );

    // Pulse animation controller for microphone glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadVoicePreference() async {
    final pitchStr = await ref.read(secureStorageProvider).read('assistant_voice_pitch');
    final rateStr = await ref.read(secureStorageProvider).read('assistant_voice_rate');
    final nameStr = await ref.read(secureStorageProvider).read('assistant_voice_name');

    if (pitchStr != null && rateStr != null) {
      setState(() {
        _currentPitch = double.tryParse(pitchStr) ?? 1.0;
        _currentRate = double.tryParse(rateStr) ?? 0.5;
        if (nameStr != null) _selectedVoiceName = nameStr;
      });
      await _applyTtsSettings();
    }
  }

  Future<void> _applyTtsSettings() async {
    try {
      await _flutterTts.setLanguage('es-ES');
      await _flutterTts.setSpeechRate(_currentRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_currentPitch);
    } catch (e) {
      debugPrint('Error setting TTS pitch/rate: $e');
    }
  }

  // Initialize Speech to Text with runtime permission check
  Future<void> _initSpeech() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() => _speechEnabled = false);
        }
        return;
      }

      final available = await _speechToText.initialize(
        onError: (val) {
          debugPrint('STT Error: $val');
          if (mounted && _isListening) {
            setState(() => _isListening = false);
          }
        },
        onStatus: (val) {
          debugPrint('STT Status: $val');
          if ((val == 'done' || val == 'notListening') && _isListening) {
            _stopListeningAndSend();
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      debugPrint('Error initializing STT: $e');
    }
  }

  bool _continuousVoiceMode = false;

  // Initialize Text to Speech
  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('es-ES');
      await _applyTtsSettings();
      _flutterTts.setCompletionHandler(() {
        if (mounted && _isSpeakerEnabled && _continuousVoiceMode && !_isListening && !_isLoading) {
          _toggleListening();
        }
      });
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  // Speak out assistant responses
  Future<void> _speak(String text) async {
    if (!_isSpeakerEnabled) return;
    await _flutterTts.stop();
    await _applyTtsSettings();
    await _flutterTts.speak(text);
  }

  void _showVoiceSelectorModal() {
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
                  const Icon(Icons.record_voice_over_rounded, color: AppTheme.primaryDark, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Personalizar Voz del Asistente',
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
              const SizedBox(height: 16),
              const Text(
                'Selecciona el estilo de voz que más te guste:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _voiceOptions.length,
                  itemBuilder: (context, idx) {
                    final opt = _voiceOptions[idx];
                    final isSelected = _selectedVoiceName == opt.name;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () async {
                          setState(() {
                            _selectedVoiceName = opt.name;
                            _currentPitch = opt.pitch;
                            _currentRate = opt.rate;
                          });
                          await ref.read(secureStorageProvider).write('assistant_voice_pitch', opt.pitch.toString());
                          await ref.read(secureStorageProvider).write('assistant_voice_rate', opt.rate.toString());
                          await ref.read(secureStorageProvider).write('assistant_voice_name', opt.name);
                          await _applyTtsSettings();

                          await _flutterTts.stop();
                          await _flutterTts.speak('Hola, este es mi tono de voz en My Reminder');
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryDark.withValues(alpha: 0.15)
                                : (isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryDark : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(opt.icon, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Text(
                                opt.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.primaryDark
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppTheme.primaryDark, size: 20),
                            ],
                          ),
                        ),
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

  // Fallback local intent parser for robust reminder creation
  ReminderModel _createLocalReminder(String queryText) {
    String lower = queryText.toLowerCase();
    String title = queryText;
    final prefixes = [
      'recuérdame ', 'recordar ', 'agendar ', 'crear tarea ', 'un recordatorio para ', 'recordatorio ',
      'tengo que ', 'debemos ', 'llamar a ', 'comprar '
    ];
    for (final p in prefixes) {
      if (title.toLowerCase().startsWith(p)) {
        title = title.substring(p.length).trim();
        break;
      }
    }
    if (title.isEmpty) title = queryText;
    title = title[0].toUpperCase() + title.substring(1);

    final now = DateTime.now();
    int year = now.year;
    int month = now.month;
    int day = now.day;
    int hour = now.hour + 1;
    int minute = 0;

    // Detect exact day of month (e.g., "el 20", "el 15 de agosto", "día 25")
    final dayMatch = RegExp(r'\b(?:el|día)\s+([0-2]?[0-9]|3[01])\b').firstMatch(lower);
    if (dayMatch != null) {
      final parsedDay = int.tryParse(dayMatch.group(1)!);
      if (parsedDay != null && parsedDay >= 1 && parsedDay <= 31) {
        day = parsedDay;
        // If parsed day is earlier than today, assume next month
        if (day < now.day && !lower.contains('pasado mañana') && !lower.contains('mañana')) {
          month = now.month == 12 ? 1 : now.month + 1;
          if (month == 1) year++;
        }
      }
    } else if (lower.contains('pasado mañana')) {
      final target = now.add(const Duration(days: 2));
      year = target.year;
      month = target.month;
      day = target.day;
    } else if (lower.contains('mañana')) {
      final target = now.add(const Duration(days: 1));
      year = target.year;
      month = target.month;
      day = target.day;
    }

    // Detect month name (e.g., "agosto", "septiembre", "octubre")
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    for (int i = 0; i < months.length; i++) {
      if (lower.contains(months[i])) {
        month = i + 1;
        break;
      }
    }

    // Detect exact hour (e.g., "a las 4", "a las 16", "a las 5 pm", "a las 8 am")
    final hourMatch = RegExp(r'\ba\s+las\s+([0-2]?[0-9])(?::([0-5][0-9]))?\s*(pm|am|de la tarde|de la mañana|de la noche)?').firstMatch(lower);
    if (hourMatch != null) {
      int parsedHour = int.tryParse(hourMatch.group(1)!) ?? hour;
      if (hourMatch.group(2) != null) {
        minute = int.tryParse(hourMatch.group(2)!) ?? 0;
      }
      final period = hourMatch.group(3);
      if (period != null && (period == 'pm' || period == 'de la tarde' || period == 'de la noche') && parsedHour < 12) {
        parsedHour += 12;
      }
      hour = parsedHour;
    }

    final dueDate = DateTime(year, month, day, hour, minute);

    return ReminderModel(
      id: 'r-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: 'Agendado mediante Asistente de Voz',
      category: lower.contains('salud') || lower.contains('médico') || lower.contains('doctor')
          ? 'Salud'
          : lower.contains('trabajo') || lower.contains('reunión') || lower.contains('oficina')
              ? 'Trabajo'
              : 'Personal',
      dueDate: dueDate,
      status: 'pending',
      isSynced: false,
      createdAt: DateTime.now(),
    );
  }

  // Toggle listening state cleanly (Tap to start / Tap to stop)
  Future<void> _toggleListening() async {
    if (_isListening) {
      _stopListeningAndSend();
    } else {
      if (!_speechEnabled) {
        await _initSpeech();
      }

      if (!_speechEnabled) {
        if (mounted) {
          AppToast.show(context, message: 'Se requiere permiso de micrófono para escuchar tu voz.', type: AppToastType.warning);
        }
        return;
      }

      await _flutterTts.stop();
      setState(() {
        _isListening = true;
        _lastWords = '';
      });

      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _lastWords = result.recognizedWords;
            });
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'es_US',
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Stop capturing audio and trigger single message send
  void _stopListeningAndSend() async {
    if (!_isListening && _isSending) return;
    await _speechToText.stop();
    
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }

    final textToSend = _lastWords.trim();
    _lastWords = '';
    if (textToSend.isNotEmpty) {
      _sendMessage(textToSend, isVoiceInput: true);
    }
  }

  // Send message to C# backend Gemini integration
  Future<void> _sendMessage(String text, {required bool isVoiceInput}) async {
    final queryText = text.trim();
    if (queryText.isEmpty || _isSending) return;

    _textController.clear();
    setState(() {
      _isSending = true;
      _messages.add(MessageItem(text: queryText, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    ReminderModel? createdReminder;
    String speechResponse = '';

    final lower = queryText.toLowerCase();
    final isDeleteIntent = lower.contains('elimina') ||
        lower.contains('borra') ||
        lower.contains('quita') ||
        lower.contains('cancela');

    try {
      final apiClient = ref.read(apiClientProvider);
      
      final response = await apiClient.post(
        '/api/assistant/talk',
        data: {'message': queryText},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
        speechResponse = data['speechResponse'] as String? ?? '';
        final String action = data['action'] as String? ?? 'talk';

        if (action == 'delete') {
          final deletedTitle = data['deletedReminderTitle'] as String?;
          final targetTitle = (deletedTitle != null && deletedTitle.isNotEmpty)
              ? deletedTitle
              : queryText.replaceAll(RegExp(r'(elimina|borra|quita|cancela)\s+(el|la|mi|recordatorio|tarea)?', caseSensitive: false), '').trim();

          final currentReminders = ref.read(remindersProvider);
          final matches = currentReminders.where((r) =>
              r.title.toLowerCase().contains(targetTitle.toLowerCase()) ||
              targetTitle.toLowerCase().contains(r.title.toLowerCase())).toList();

          for (final m in matches) {
            await ref.read(remindersProvider.notifier).deleteReminder(m.id);
          }

          if (matches.isNotEmpty) {
            speechResponse = speechResponse.isNotEmpty
                ? speechResponse
                : '¡Listo! He eliminado "${matches.first.title}" de tu Agenda.';
            if (mounted) {
              AppToast.show(context, message: '¡Eliminado de tu Agenda!', type: AppToastType.warning);
            }
          } else {
            speechResponse = speechResponse.isNotEmpty
                ? speechResponse
                : 'No encontré ningún recordatorio en tu Agenda que coincida para eliminar.';
          }
        } else if (action == 'create' && data['createdReminder'] != null) {
          final reminderJson = Map<String, dynamic>.from(data['createdReminder'] as Map);
          createdReminder = ReminderModel(
            id: reminderJson['id'] as String,
            title: reminderJson['title'] as String,
            description: reminderJson['description'] as String?,
            category: reminderJson['category'] as String? ?? 'General',
            dueDate: DateTime.parse(reminderJson['dueDate'] as String).toLocal(),
            status: reminderJson['status'] as String? ?? 'pending',
            isSynced: true,
            createdAt: DateTime.parse(reminderJson['createdAt'] as String).toLocal(),
          );
        }
      }
    } catch (_) {
      // Backend offline or error fallback
    }

    // Fallback local deletion or creation if backend didn't handle it
    if (isDeleteIntent && speechResponse.isEmpty) {
      String targetTitle = queryText.replaceAll(RegExp(r'(elimina|borra|quita|cancela)\s+(el|la|mi|recordatorio|tarea)?', caseSensitive: false), '').trim();
      final currentReminders = ref.read(remindersProvider);
      final matches = currentReminders.where((r) =>
          r.title.toLowerCase().contains(targetTitle.toLowerCase()) ||
          targetTitle.toLowerCase().contains(r.title.toLowerCase())).toList();

      if (matches.isNotEmpty) {
        for (final m in matches) {
          await ref.read(remindersProvider.notifier).deleteReminder(m.id);
        }
        speechResponse = '¡Listo! He eliminado "${matches.first.title}" de tu Agenda.';
        if (mounted) {
          AppToast.show(context, message: '¡Eliminado de tu Agenda!', type: AppToastType.warning);
        }
      } else {
        speechResponse = 'No encontré ningún recordatorio en tu Agenda con el nombre "$targetTitle" para eliminar.';
      }
    }

    final hasReminderIntent = lower.contains('recuérdame') ||
        lower.contains('recordar') ||
        lower.contains('agendar') ||
        lower.contains('crear tarea') ||
        lower.contains('cita') ||
        lower.contains('reunión') ||
        lower.contains('comprar') ||
        lower.contains('tengo que') ||
        lower.contains('llamar');

    if (createdReminder == null && hasReminderIntent && !isDeleteIntent) {
      createdReminder = _createLocalReminder(queryText);
      speechResponse = '¡Entendido! He agendado "${createdReminder.title}" en tu Agenda principal para el ${DateFormat('dd/MM/yyyy HH:mm').format(createdReminder.dueDate)}.';
    }

    if (speechResponse.isEmpty) {
      speechResponse = '¡Te escucho perfectamente! ¿En qué más te puedo ayudar hoy con tu agenda?';
    }

    if (createdReminder != null) {
      await ref.read(localReminderRepositoryProvider).insertReminder(createdReminder);
      await ref.read(remindersProvider.notifier).loadReminders();

      if (mounted) {
        AppToast.show(
          context,
          message: '¡Agendado en tu Agenda: "${createdReminder.title}"!',
          type: AppToastType.success,
        );
      }
    }

    if (mounted) {
      setState(() {
        _messages.add(MessageItem(
          text: speechResponse,
          isUser: false,
          createdReminder: createdReminder,
        ));
      });
    }

    _scrollToBottom();

    if (isVoiceInput && _isSpeakerEnabled) {
      await _speak(speechResponse);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente IA de Voz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _continuousVoiceMode ? Icons.forum_rounded : Icons.forum_outlined,
              color: _continuousVoiceMode ? AppTheme.accentTeal : Colors.grey,
            ),
            tooltip: _continuousVoiceMode ? 'Modo Charla Continua ACTIVADO' : 'Modo Charla Continua DESACTIVADO',
            onPressed: () {
              setState(() {
                _continuousVoiceMode = !_continuousVoiceMode;
              });
              AppToast.show(
                context,
                message: _continuousVoiceMode
                    ? '💬 Modo Charla Continua ACTIVADO: Mulan te escuchará tras responder.'
                    : 'Modo Charla Continua DESACTIVADO',
                type: _continuousVoiceMode ? AppToastType.success : AppToastType.info,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.primaryDark),
            tooltip: 'Configurar Opciones de Voz',
            onPressed: _showVoiceSelectorModal,
          ),
          IconButton(
            icon: Icon(
              _isSpeakerEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _isSpeakerEnabled ? AppTheme.primaryDark : Colors.grey,
            ),
            tooltip: _isSpeakerEnabled ? 'Audio respuesta activado' : 'Audio respuesta desactivado',
            onPressed: () {
              setState(() {
                _isSpeakerEnabled = !_isSpeakerEnabled;
              });
              if (!_isSpeakerEnabled) {
                _flutterTts.stop();
              }
              AppToast.show(
                context,
                message: _isSpeakerEnabled ? 'Audio de respuesta ACTIVADO' : 'Audio de respuesta DESACTIVADO',
                type: AppToastType.info,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat history list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: msg.isUser
                                  ? AppTheme.primaryDark
                                  : (isDark ? AppTheme.surfaceDark : Colors.grey[200]),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: msg.isUser ? const Radius.circular(18) : Radius.zero,
                                bottomRight: msg.isUser ? Radius.zero : const Radius.circular(18),
                              ),
                              border: Border.all(
                                color: msg.isUser
                                    ? AppTheme.primaryDark
                                    : (isDark ? AppTheme.glassBorder : Colors.transparent),
                              ),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: msg.isUser
                                    ? Colors.black
                                    : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                                height: 1.4,
                              ),
                            ),
                          ),

                          // If this response created a reminder, show a dedicated interactive badge card!
                          if (msg.createdReminder != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.75,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: AppTheme.accentTeal, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Recordatorio Guardado en Agenda',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    msg.createdReminder!.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.event_rounded, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('dd MMM yyyy, HH:mm').format(msg.createdReminder!.dueDate),
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryDark.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          msg.createdReminder!.category,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: GaxxsLoader(showBrandName: false, size: 36),
              ),

            // Live speech transcription bar
            if (_isListening)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastWords.isEmpty ? 'Escuchando tu voz... Toca el micro al terminar' : _lastWords,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.redAccent),
                      onPressed: _stopListeningAndSend,
                    ),
                  ],
                ),
              ),

            // INPUT & VOICE CONTROL PANEL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.glassBorder : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje o duda de la app...',
                        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (val) => _sendMessage(val, isVoiceInput: false),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send text button (if typing text) or Mic button
                  _textController.text.trim().isNotEmpty
                      ? CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryDark,
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                            onPressed: () => _sendMessage(_textController.text, isVoiceInput: false),
                          ),
                        )
                      : GestureDetector(
                          onTap: _toggleListening,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final double pulse = 1.0 + (_pulseController.value * 0.15);
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isListening ? Colors.redAccent : AppTheme.primaryDark)
                                          .withValues(alpha: _isListening ? 0.5 : 0.25),
                                      blurRadius: _isListening ? 20 * pulse : 10,
                                      spreadRadius: _isListening ? 4 * pulse : 1,
                                    ),
                                  ],
                                ),
                                child: Transform.scale(
                                  scale: _isListening ? pulse : 1.0,
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: _isListening ? Colors.redAccent : AppTheme.primaryDark,
                                    child: Icon(
                                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                      size: 24,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
