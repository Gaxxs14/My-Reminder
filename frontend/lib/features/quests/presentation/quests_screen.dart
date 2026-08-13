import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../habits/presentation/habits_provider.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsNotifier = ref.read(habitsProvider.notifier);

    final List<Map<String, dynamic>> dailyQuests = [
      {'title': 'Completa 3 tareas de Trabajo', 'xp': 50, 'completed': true, 'icon': Icons.work_rounded},
      {'title': 'Realiza 1 sesión de Pomodoro (25 min)', 'xp': 25, 'completed': false, 'icon': Icons.timer_rounded},
      {'title': 'Registra tu estado de ánimo de hoy', 'xp': 10, 'completed': false, 'icon': Icons.mood_rounded},
    ];

    final List<Map<String, dynamic>> badges = [
      {'name': 'Madrugador', 'desc': 'Completa 1 tarea antes de las 9 AM', 'icon': '🌅', 'unlocked': true},
      {'name': 'Leyenda del Enfoque', 'desc': 'Completa 5 sesiones de Pomodoro', 'icon': '🏆', 'unlocked': true},
      {'name': 'Maestro de la Rutina', 'desc': 'Racha de 7 días consecutivos', 'icon': '⚡', 'unlocked': false},
      {'name': 'Explorador IA', 'desc': 'Usa búsqueda semántica de notas', 'icon': '🤖', 'unlocked': true},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Misiones RPG & Logros', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current XP Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF2DD4BF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 44, color: Colors.black),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Puntos de Experiencia (XP)',
                          style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${habitsNotifier.totalPoints} XP acumulados',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Daily Quests Section
              Text(
                'Misiones Diarias',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              Column(
                children: dailyQuests.map((q) {
                  final isDone = q['completed'] as bool;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDone ? AppTheme.accentTeal : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                        width: isDone ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(q['icon'] as IconData, color: isDone ? AppTheme.accentTeal : Colors.grey),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '+${q['xp']} XP Recompensa',
                                style: const TextStyle(fontSize: 11, color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        if (isDone)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.accentTeal)
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryDark,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              ref.read(habitsProvider.notifier).addPoints(q['xp'] as int);
                              AppToast.show(context, message: '¡Misión reclamada! (+${q['xp']} XP)', type: AppToastType.success);
                            },
                            child: const Text('Reclamar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Badges & Achievements Section
              Text(
                'Insignias & Logros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final b = badges[index];
                  final unlocked = b['unlocked'] as bool;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: unlocked ? AppTheme.primaryDark : (isDark ? AppTheme.glassBorder : Colors.grey[200]!),
                        width: unlocked ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(b['icon'] as String, style: const TextStyle(fontSize: 28)),
                            if (unlocked)
                              const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b['name'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: unlocked ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                          ),
                        ),
                        Text(
                          b['desc'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
