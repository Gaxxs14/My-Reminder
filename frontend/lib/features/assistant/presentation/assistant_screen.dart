import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  MessageItem({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isLoading = false;
  String _lastWords = '';
  
  final List<MessageItem> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    
    // Add welcome message from Assistant
    _messages.add(
      MessageItem(
        text: '¡Hola! Soy tu asistente de My-Reminder. Presiona el micrófono y dime qué deseas agendar, por ejemplo: "Recuérdame comprar pan mañana a las 5 de la tarde".',
        isUser: false,
      ),
    );

    // Pulse animation controller for the microphone glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Initialize Speech to Text
  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) => debugPrint('STT Status: $val'),
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

  // Initialize Text to Speech
  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('es');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  // Speak out assistant responses
  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  // Start capturing audio
  void _startListening() async {
    if (!_speechEnabled) {
      AppToast.show(context, message: 'El micrófono no está habilitado.', type: AppToastType.warning);
      return;
    }
    
    await _flutterTts.stop();
    setState(() {
      _isListening = true;
      _lastWords = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });
      },
      listenOptions: SpeechListenOptions(localeId: 'es_US'),
    );
  }

  // Stop capturing audio and process request
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    if (_lastWords.trim().isNotEmpty) {
      _sendMessage(_lastWords);
    }
  }

  // Send message to C# backend Gemini integration
  Future<void> _sendMessage(String text) async {
    setState(() {
      _messages.add(MessageItem(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final apiClient = ref.read(apiClientProvider);
      
      // POST user text to backend C# AI Assistant endpoint
      final response = await apiClient.post(
        '/api/assistant/talk',
        data: {'message': text},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
        final String speechResponse = data['speechResponse'] as String? ?? 'Entendido.';
        final String action = data['action'] as String? ?? 'talk';

        setState(() {
          _messages.add(MessageItem(text: speechResponse, isUser: false));
        });
        _scrollToBottom();
        
        // Speak assistant response aloud
        await _speak(speechResponse);

        // If the backend automatically created a reminder in PostgreSQL, save it locally in SQLite
        if (action == 'create' && data['createdReminder'] != null) {
          final reminderJson = Map<String, dynamic>.from(data['createdReminder'] as Map);
          
          final localReminder = ReminderModel(
            id: reminderJson['id'] as String,
            title: reminderJson['title'] as String,
            description: reminderJson['description'] as String?,
            category: reminderJson['category'] as String? ?? 'General',
            dueDate: DateTime.parse(reminderJson['dueDate'] as String).toLocal(),
            status: reminderJson['status'] as String? ?? 'pending',
            isSynced: true, // It is already saved in the cloud DB
            createdAt: DateTime.parse(reminderJson['createdAt'] as String).toLocal(),
          );

          // Insert into local SQLite database cache
          await ref.read(remindersProvider.notifier).addReminder(localReminder);
          
          if (mounted) {
            AppToast.show(context, message: '¡Recordatorio agendado por voz!', type: AppToastType.success);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: 'Error de conexión con el Asistente: $e', type: AppToastType.error);
        setState(() {
          _messages.add(MessageItem(
            text: 'Lo siento, no pude procesar tu solicitud por un problema de red. Por favor intenta de nuevo.',
            isUser: false,
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
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
        title: const Text('Asistente de Voz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                              : (isDark ? AppTheme.surfaceDark : Colors.grey[200]),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
                            bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
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
                margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.surfaceDark : Colors.grey[100])!.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryDark.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastWords.isEmpty ? 'Escuchando tu voz...' : _lastWords,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Pulsing Microphone Panel
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTapDown: (_) => _startListening(),
                      onTapUp: (_) => _stopListening(),
                      onTapCancel: () => _stopListening(),
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
                                      .withValues(alpha: _isListening ? 0.4 : 0.2),
                                  blurRadius: _isListening ? 24 * pulse : 12,
                                  spreadRadius: _isListening ? 6 * pulse : 2,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: _isListening ? pulse : 1.0,
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: _isListening ? Colors.redAccent : AppTheme.primaryDark,
                                child: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  size: 32,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isListening ? 'Suelta para enviar' : 'Mantén presionado para hablar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
