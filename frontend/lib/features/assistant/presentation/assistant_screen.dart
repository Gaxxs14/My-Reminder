import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final TextEditingController _textController = TextEditingController();
  
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSending = false;
  bool _isSpeakerEnabled = true;
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
        text: '¡Hola! Soy tu asistente de My Reminder. Toca el micrófono para hablar o escribe tu mensaje abajo, por ejemplo: "Recuérdame comprar fruta mañana a las 5 PM".',
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

  // Initialize Text to Speech
  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('es-ES');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  // Speak out assistant responses
  Future<void> _speak(String text) async {
    if (!_isSpeakerEnabled) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
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

    try {
      final apiClient = ref.read(apiClientProvider);
      
      // POST user text to backend C# AI Assistant endpoint
      final response = await apiClient.post(
        '/api/assistant/talk',
        data: {'message': queryText},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response.data as Map);
        final String speechResponse = data['speechResponse'] as String? ?? 'Entendido.';
        final String action = data['action'] as String? ?? 'talk';

        if (mounted) {
          setState(() {
            _messages.add(MessageItem(text: speechResponse, isUser: false));
          });
        }
        _scrollToBottom();
        
        // Speak assistant response aloud ONLY if user spoke by voice and speaker is enabled
        if (isVoiceInput && _isSpeakerEnabled) {
          await _speak(speechResponse);
        }

        // If backend created a reminder, save it locally in SQLite
        if (action == 'create' && data['createdReminder'] != null) {
          final reminderJson = Map<String, dynamic>.from(data['createdReminder'] as Map);
          
          final localReminder = ReminderModel(
            id: reminderJson['id'] as String,
            title: reminderJson['title'] as String,
            description: reminderJson['description'] as String?,
            category: reminderJson['category'] as String? ?? 'General',
            dueDate: DateTime.parse(reminderJson['dueDate'] as String).toLocal(),
            status: reminderJson['status'] as String? ?? 'pending',
            isSynced: true,
            createdAt: DateTime.parse(reminderJson['createdAt'] as String).toLocal(),
          );

          await ref.read(remindersProvider.notifier).addReminder(localReminder);
          
          if (mounted) {
            AppToast.show(context, message: '¡Recordatorio agendado por voz!', type: AppToastType.success);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final fallbackMsg = 'Entendido. He registrado tu consulta: "$queryText".';
        setState(() {
          _messages.add(MessageItem(text: fallbackMsg, isUser: false));
        });
        if (isVoiceInput && _isSpeakerEnabled) {
          _speak(fallbackMsg);
        }
        AppToast.show(context, message: 'Modo fuera de línea activado.', type: AppToastType.info);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSending = false;
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
                      child: Container(
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
                        hintText: 'Escribe un mensaje...',
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
