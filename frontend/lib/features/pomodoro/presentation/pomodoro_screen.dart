import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../reminders/presentation/reminders_provider.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> with SingleTickerProviderStateMixin {
  final int _workMinutes = 25;
  final int _breakMinutes = 5;
  bool _isWorkMode = true;
  bool _isRunning = false;
  late int _remainingSeconds;
  Timer? _timer;
  int _completedSessions = 0;
  String? _selectedTaskId;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _workMinutes * 60;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _handleSessionComplete();
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
      _remainingSeconds = (_isWorkMode ? _workMinutes : _breakMinutes) * 60;
    });
  }

  void _switchMode(bool isWork) {
    _timer?.cancel();
    setState(() {
      _isWorkMode = isWork;
      _isRunning = false;
      _remainingSeconds = (isWork ? _workMinutes : _breakMinutes) * 60;
    });
  }

  void _handleSessionComplete() {
    if (_isWorkMode) {
      setState(() {
        _completedSessions++;
      });
      AppToast.show(context, message: '🎉 ¡Sesión de concentración completada! Tómate un descanso.', type: AppToastType.success);
      _switchMode(false);
    } else {
      AppToast.show(context, message: '☕ ¡Descanso terminado! Listo para enfocarte.', type: AppToastType.info);
      _switchMode(true);
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    final total = (_isWorkMode ? _workMinutes : _breakMinutes) * 60;
    if (total == 0) return 0;
    return (_remainingSeconds / total);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminders = ref.watch(remindersProvider).where((r) => r.status != 'completed').toList();

    final activeColor = _isWorkMode ? AppTheme.accentIndigo : const Color(0xFF10B981);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Enfoque • Pomodoro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetTimer,
            tooltip: 'Reiniciar',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Selector de Modo (Enfoque / Descanso)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton('Concentración', true, activeColor),
                    _buildModeButton('Descanso', false, const Color(0xFF10B981)),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Temporizador Circular
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: _getProgress(),
                      strokeWidth: 10,
                      backgroundColor: activeColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isWorkMode ? '🎯 ENFOCADO' : '☕ DESCANSO',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: activeColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Botones de Control
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: activeColor,
                      padding: const EdgeInsets.all(18),
                    ),
                    icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36, color: Colors.white),
                    onPressed: () {
                      if (_isRunning) {
                        _pauseTimer();
                      } else {
                        _startTimer();
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Tarea Vinculada
              if (reminders.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDarkElevated : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedTaskId,
                      hint: const Text('Vincular a una tarea de tu agenda...', style: TextStyle(fontSize: 13)),
                      items: reminders.map((r) {
                        return DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTaskId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Contador de Sesiones Completadas
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Sesiones Hoy', '$_completedSessions', Icons.local_fire_department_rounded, Colors.orange),
                    _buildStatItem('Minutos Enfocado', '${_completedSessions * 25} min', Icons.timer_rounded, AppTheme.accentIndigo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String title, bool isWork, Color color) {
    final isSelected = _isWorkMode == isWork;
    return GestureDetector(
      onTap: () => _switchMode(isWork),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
