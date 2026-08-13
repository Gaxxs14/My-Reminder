import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../habits/presentation/habits_provider.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  static const int _defaultSeconds = 25 * 60; // 25 Minutes
  int _remainingSeconds = _defaultSeconds;
  Timer? _timer;
  bool _isRunning = false;
  String _selectedSound = 'Lluvia';
  bool _isZenMode = false;

  final List<Map<String, dynamic>> _sounds = [
    {'name': 'Sin Audio', 'icon': Icons.volume_off_rounded},
    {'name': 'Lluvia', 'icon': Icons.water_drop_rounded},
    {'name': 'Bosque', 'icon': Icons.park_rounded},
    {'name': 'Café', 'icon': Icons.local_cafe_rounded},
    {'name': 'Ruido Blanco', 'icon': Icons.graphic_eq_rounded},
  ];

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _onPomodoroCompleted();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _defaultSeconds;
    });
  }

  void _onPomodoroCompleted() {
    ref.read(habitsProvider.notifier).addPoints(25);
    AppToast.show(context, message: '🎉 ¡Sesión Pomodoro completada! (+25 XP)', type: AppToastType.success);
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = 1 - (_remainingSeconds / _defaultSeconds);

    if (_isZenMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70, size: 28),
                  onPressed: () => setState(() => _isZenMode = false),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MODO ZEN',
                      style: TextStyle(fontSize: 14, letterSpacing: 4, color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -2),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sonido ambiental: $_selectedSound',
                      style: const TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temporizador Pomodoro', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: 'Modo Zen Escritorio',
            onPressed: () => setState(() => _isZenMode = true),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                'Mantén el enfoque en tus tareas',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const Spacer(),

              // Circular Progress Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryDark),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRunning ? 'EN CONCENTRACIÓN' : 'EN PAUSA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: _isRunning ? AppTheme.accentTeal : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Ambient Sound Selector Chips
              Text(
                'Música Ambiental de Fondo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sounds.length,
                  itemBuilder: (context, idx) {
                    final snd = _sounds[idx];
                    final isSelected = _selectedSound == snd['name'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(snd['icon'] as IconData, size: 16, color: isSelected ? Colors.black : AppTheme.primaryDark),
                        label: Text(snd['name'] as String),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryDark,
                        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedSound = snd['name'] as String);
                            AppToast.show(context, message: 'Audio: ${snd['name']}', type: AppToastType.info);
                          }
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              // Control Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[200],
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.grey, size: 28),
                    onPressed: _resetTimer,
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _isRunning ? _pauseTimer : _startTimer,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryDark.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 40,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
